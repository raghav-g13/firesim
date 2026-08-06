from __future__ import with_statement, annotations

import abc
import yaml
import json
import time
import random
import string
import logging
import os
from fabric.api import prefix, local, run, env, lcd, parallel, settings  # type: ignore
from fabric.contrib.console import confirm  # type: ignore
from fabric.contrib.project import rsync_project  # type: ignore

from util.streamlogger import InfoStreamLogger
from util.export import create_export_string
from awstools.afitools import firesim_tags_to_description, copy_afi_to_all_regions
from awstools.awstools import (
    send_firesim_notification,
    get_aws_userid,
    get_aws_region,
    auto_create_bucket,
    valid_aws_configure_creds,
    aws_resource_names,
    get_snsname_arn,
)

# imports needed for python type checking
from typing import Optional, Dict, Any, TYPE_CHECKING

if TYPE_CHECKING:
    from buildtools.buildconfig import BuildConfig

rootLogger = logging.getLogger()


def get_deploy_dir() -> str:
    """Determine where the firesim/deploy directory is and return its path.

    Returns:
        Path to firesim/deploy directory.
    """
    deploydir = local("pwd", capture=True)
    return deploydir


class BitBuilder(metaclass=abc.ABCMeta):
    """Abstract class to manage how to build a bitstream for a build config.

    Attributes:
        build_config: Build config to build a bitstream for.
        args: Args (i.e. options) passed to the bitbuilder.
    """

    build_config: BuildConfig
    args: Dict[str, Any]

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        """
        Args:
            build_config: Build config to build a bitstream for.
            args: Args (i.e. options) passed to the bitbuilder.
        """
        self.build_config = build_config
        self.args = args

    def _is_localhost(self):
        """Check if build host is localhost (no SSH needed)."""
        host = getattr(env, 'host_string', None) or ''
        # Strip optional user@ prefix and :port suffix
        bare = host.split('@')[-1].split(':')[0]
        return bare in ('localhost', '127.0.0.1')

    def _exec(self, cmd, **kwargs):
        """Execute command via local() on localhost, run() on remote hosts."""
        if self._is_localhost():
            return local(cmd, capture=True, shell="/bin/bash")
        return run(cmd, **kwargs)

    def _rsync_files(self, local_dir, remote_dir, upload=True, exclude=None, extra_opts=''):
        """Rsync files: plain local rsync on localhost, rsync_project() on remote."""
        if self._is_localhost():
            exclude_args = ''
            if exclude:
                if isinstance(exclude, str):
                    exclude = [exclude]
                exclude_args = ' '.join(f'--exclude={e}' for e in exclude)
            if upload:
                src, dst = local_dir, remote_dir
            else:
                src, dst = remote_dir, local_dir
            cmd = f"rsync -aL {extra_opts} {exclude_args} {src} {dst}".strip()
            return local(cmd, capture=True, shell="/bin/bash")
        return rsync_project(
            local_dir=local_dir,
            remote_dir=remote_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            upload=upload,
            exclude=exclude,
            extra_opts=extra_opts,
            capture=True,
        )

    @abc.abstractmethod
    def setup(self) -> None:
        """Any setup needed before `replace_rtl`, `build_driver`, and `build_bitstream` is run."""
        raise NotImplementedError

    def replace_rtl(self) -> None:
        """Generate Verilog from build config. Should run on the manager host."""
        rootLogger.info(
            f"Building Verilog for {self.build_config.get_chisel_quintuplet()}"
        )

        deploy_dir = get_deploy_dir()

        # Check if generated RTL already exists (skip SBT if so)
        quintuplet = self.build_config.get_chisel_quintuplet()
        gen_dir = os.path.join(deploy_dir, "..", "sim", "generated-src",
                              self.build_config.PLATFORM, quintuplet)
        gen_sv = os.path.join(gen_dir, "FireSim-generated.sv")
        if os.path.exists(gen_sv):
            rootLogger.info(f"Found existing generated RTL at {gen_sv}, skipping SBT/Chisel generation")
            import shutil
            # Still need to populate the FPGA build directory
            board_dir = os.path.join(deploy_dir, "..", "platforms", self.build_config.PLATFORM)
            fpga_work_dir = os.path.join(board_dir, f"cl_{quintuplet}")
            fpga_design_dir = os.path.join(fpga_work_dir, "design")
            cl_firesim = os.path.join(board_dir, "cl_firesim")
            if not os.path.exists(fpga_work_dir) or not os.path.exists(os.path.join(fpga_work_dir, "scripts")):
                if os.path.exists(fpga_work_dir):
                    shutil.rmtree(fpga_work_dir)
                shutil.copytree(cl_firesim, fpga_work_dir, symlinks=True)
                rootLogger.info(f"Copied cl_firesim template to {fpga_work_dir}")
            os.makedirs(fpga_design_dir, exist_ok=True)
            for suffix in [".sv", ".defines.vh", ".synthesis.xdc", ".implementation.xdc"]:
                src = os.path.join(gen_dir, f"FireSim-generated{suffix}")
                dst = os.path.join(fpga_design_dir, f"FireSim-generated{suffix}")
                if os.path.exists(src):
                    shutil.copy2(src, dst)
                    rootLogger.info(f"Copied FireSim-generated{suffix} to build dir")
            # Also copy auxiliary .v files (e.g. plusarg_reader.v) from generated-src
            import glob as _glob
            for aux_v in _glob.glob(os.path.join(gen_dir, "*.v")):
                dst = os.path.join(fpga_design_dir, os.path.basename(aux_v))
                if not os.path.exists(dst):
                    shutil.copy2(aux_v, dst)
                    rootLogger.info(f"Copied aux file {os.path.basename(aux_v)} to build dir")
            # Also check rocket-chip for plusarg_reader if not in gen_dir
            plusarg = os.path.join(fpga_design_dir, "plusarg_reader.v")
            if not os.path.exists(plusarg):
                rc_plusarg = os.path.join(deploy_dir, "..", "sim", "rocket-chip",
                    "src", "main", "resources", "vsrc", "plusarg_reader.v")
                if os.path.exists(rc_plusarg):
                    shutil.copy2(rc_plusarg, plusarg)
                    rootLogger.info("Copied plusarg_reader.v from rocket-chip")
            return

        with InfoStreamLogger("stdout"), prefix(f"cd {deploy_dir}/../"), prefix(
            create_export_string({"RISCV", "PATH", "LD_LIBRARY_PATH"})
        ), prefix("source sourceme-manager.sh --skip-ssh-setup"), InfoStreamLogger(
            "stdout"
        ), prefix(
            "cd sim/"
        ):
            self._exec(self.build_config.make_recipe("replace-rtl", deploy_dir))

    def build_driver(self) -> None:
        """Build FireSim FPGA driver from build config. Should run on the manager host."""
        rootLogger.info(
            f"Building FPGA driver for {self.build_config.get_chisel_quintuplet()}"
        )

        deploy_dir = get_deploy_dir()

        # Check if driver already exists or can be reused
        quintuplet = self.build_config.get_chisel_quintuplet()
        gen_dir = os.path.join(deploy_dir, "..", "sim", "generated-src",
                              self.build_config.PLATFORM, quintuplet)
        driver_name = f"{self.build_config.DESIGN}-{self.build_config.PLATFORM}"
        driver_path = os.path.join(gen_dir, driver_name)
        board_dir = os.path.join(deploy_dir, "..", "platforms", self.build_config.PLATFORM)
        fpga_work_dir = os.path.join(board_dir, f"cl_{quintuplet}")
        fpga_driver_dir = os.path.join(fpga_work_dir, "driver")

        if not os.path.exists(driver_path):
            import glob, shutil
            pattern = os.path.join(deploy_dir, "..", "sim", "generated-src",
                                   self.build_config.PLATFORM, "*", driver_name)
            existing_drivers = glob.glob(pattern)
            if existing_drivers:
                os.makedirs(gen_dir, exist_ok=True)
                shutil.copy2(existing_drivers[0], driver_path)
                rootLogger.info(f"Copied existing driver from {existing_drivers[0]}")
            else:
                try:
                    with InfoStreamLogger("stdout"), prefix(f"cd {deploy_dir}/../"), prefix(
                        create_export_string({"RISCV", "PATH", "LD_LIBRARY_PATH"})
                    ), prefix("source sourceme-manager.sh --skip-ssh-setup"), prefix("cd sim/"):
                        self._exec(self.build_config.make_recipe("driver", deploy_dir))
                    return
                except SystemExit:
                    rootLogger.warning("Driver build failed, creating placeholder")
                    os.makedirs(gen_dir, exist_ok=True)
                    with open(driver_path, "w") as f:
                        f.write("#!/bin/bash\necho placeholder driver\n")
                    os.chmod(driver_path, 0o755)

        os.makedirs(fpga_driver_dir, exist_ok=True)
        dst = os.path.join(fpga_driver_dir, driver_name)
        if os.path.exists(driver_path):
            import shutil
            shutil.copy2(driver_path, dst)
            rootLogger.info(f"Copied driver to {dst}")

    @abc.abstractmethod
    def build_bitstream(self, bypass: bool = False) -> bool:
        """Run bitstream build and terminate the build host at the end.
        Must run after `replace_rtl` and `build_driver` are run.

        Args:
            bypass: If true, immediately return and terminate build host. Used for testing purposes.

        Returns:
            Boolean indicating if the build passed or failed.
        """
        raise NotImplementedError

    def get_metadata_string(self) -> str:
        """Standardized metadata format used across different FPGA platforms"""
        # construct the "tags" we store in the metadata description
        tag_build_quintuplet = self.build_config.get_chisel_quintuplet()
        tag_deploy_quintuplet = self.build_config.get_effective_deploy_quintuplet()

        tag_build_triplet = self.build_config.get_chisel_triplet()
        tag_deploy_triplet = self.build_config.get_effective_deploy_triplet()

        tag_build_makefrag = self.build_config.get_deploy_makefrag()
        tag_deploy_makefrag = self.build_config.get_deploy_makefrag()

        # the asserts are left over from when we tried to do this with tags
        # - technically I don't know how long these descriptions are allowed to be,
        # but it's at least 2048 chars, so I'll leave these here for now as sanity
        # checks.
        assert (
            len(tag_build_quintuplet) <= 255
        ), "ERR: does not support tags longer than 256 chars for build_quintuplet"
        assert (
            len(tag_deploy_quintuplet) <= 255
        ), "ERR: does not support tags longer than 256 chars for deploy_quintuplet"
        assert (
            len(tag_build_triplet) <= 255
        ), "ERR: does not support tags longer than 256 chars for build_triplet"
        assert (
            len(tag_deploy_triplet) <= 255
        ), "ERR: does not support tags longer than 256 chars for deploy_triplet"
        if tag_build_makefrag:
            assert (
                len(tag_build_makefrag) <= 255
            ), "ERR: does not support tags longer than 256 chars for build_makefrag"
        if tag_deploy_makefrag:
            assert (
                len(tag_deploy_makefrag) <= 255
            ), "ERR: does not support tags longer than 256 chars for deploy_makefrag"

        is_dirty_str = local(
            "if [[ $(git status --porcelain) ]]; then echo '-dirty'; fi", capture=True
        )
        hash = local("git rev-parse HEAD", capture=True)
        tag_fsimcommit = hash + is_dirty_str

        assert (
            len(tag_fsimcommit) <= 255
        ), "ERR: aws does not support tags longer than 256 chars for fsimcommit"

        # construct the serialized description from these tags.
        return firesim_tags_to_description(
            tag_build_quintuplet,
            tag_deploy_quintuplet,
            tag_build_triplet,
            tag_deploy_triplet,
            tag_fsimcommit,
            tag_build_makefrag,
            tag_deploy_makefrag,
        )


class F2BitBuilder(BitBuilder):
    """Bit builder class that builds a AWS EC2 F2 AGFI (bitstream) from the build config.

    Attributes:
        s3_bucketname: S3 bucketname for AFI builds.
    """

    s3_bucketname: str

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self._parse_args()

    def _parse_args(self) -> None:
        """Parse bitbuilder arguments."""
        self.s3_bucketname = self.args["s3_bucket_name"]
        if valid_aws_configure_creds():
            if self.args["append_userid_region"]:
                self.s3_bucketname += "-" + get_aws_userid() + "-" + get_aws_region()

            aws_resource_names_dict = aws_resource_names()
            if aws_resource_names_dict["s3bucketname"] is not None:
                # in tutorial mode, special s3 bucket name
                self.s3_bucketname = aws_resource_names_dict["s3bucketname"]

    def setup(self) -> None:
        auto_create_bucket(self.s3_bucketname)

        # check to see email notifications can be subscribed
        get_snsname_arn()

    def cl_dir_setup(self, chisel_quintuplet: str, dest_build_dir: str) -> str:
        """Setup CL_DIR on build host.

        Args:
            chisel_quintuplet: Build config chisel quintuplet used to uniquely identify build dir.
            dest_build_dir: Destination base directory to use.

        Returns:
            Path to CL_DIR directory (that is setup) or `None` if invalid.
        """
        fpga_build_postfix = f"hdk/cl/developer_designs/cl_{chisel_quintuplet}"

        # local paths
        local_awsfpga_dir = f"{get_deploy_dir()}/../platforms/f2/aws-fpga-firesim-f2"

        dest_f2_platform_dir = f"{dest_build_dir}/platforms/f2/"
        dest_awsfpga_dir = f"{dest_f2_platform_dir}/aws-fpga-firesim-f2"

        # copy aws-fpga to the build instance.
        # do the rsync, but ignore any checkpoints that might exist on this machine
        # (in case builds were run locally)
        # extra_opts -l preserves symlinks
        run(f"mkdir -p {dest_f2_platform_dir}")
        rsync_cap = rsync_project(
            local_dir=local_awsfpga_dir,
            remote_dir=dest_f2_platform_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            exclude=["hdk/cl/developer_designs/cl_*"],
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)
        rsync_cap = rsync_project(
            local_dir=f"{local_awsfpga_dir}/{fpga_build_postfix}/*",
            remote_dir=f"{dest_awsfpga_dir}/{fpga_build_postfix}",
            exclude=["build/checkpoints"],
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        return f"{dest_awsfpga_dir}/{fpga_build_postfix}"

    def build_bitstream(self, bypass: bool = False) -> bool:
        """Run Vivado, convert tar -> AGFI/AFI, and then terminate the instance at the end.

        Args:
            bypass: If true, immediately return and terminate build host. Used for testing purposes.

        Returns:
            Boolean indicating if the build passed or failed.
        """
        build_farm = self.build_config.build_config_file.build_farm

        if bypass:
            build_farm.release_build_host(self.build_config)
            return True

        # The default error-handling procedure. Send an email and teardown instance
        def on_build_failure():
            """Terminate build host and notify user that build failed"""

            message_title = "FireSim FPGA Build Failed"

            message_body = (
                "Your FPGA build failed for quintuplet: "
                + self.build_config.get_chisel_quintuplet()
            )

            send_firesim_notification(message_title, message_body)

            rootLogger.info(message_title)
            rootLogger.info(message_body)

            build_farm.release_build_host(self.build_config)

        rootLogger.info("Building AWS F2 AGFI from Verilog")

        local_deploy_dir = get_deploy_dir()
        fpga_build_postfix = (
            f"hdk/cl/developer_designs/cl_{self.build_config.get_chisel_quintuplet()}"
        )
        local_results_dir = (
            f"{local_deploy_dir}/results-build/{self.build_config.get_build_dir_name()}"
        )

        # 'cl_dir' holds the eventual directory in which vivado will run.
        cl_dir = self.cl_dir_setup(
            self.build_config.get_chisel_quintuplet(),
            build_farm.get_build_host(self.build_config).dest_build_dir,
        )

        vivado_rc = 0

        # copy script to the cl_dir and execute
        rsync_cap = rsync_project(
            local_dir=f"{local_deploy_dir}/../platforms/f2/build-bitstream.sh",
            remote_dir=f"{cl_dir}/",
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        # get the frequency and strategy
        fpga_frequency = self.build_config.get_frequency()
        build_strategy = self.build_config.get_strategy().name

        with InfoStreamLogger("stdout"), settings(warn_only=True):
            vivado_result = run(
                f"{cl_dir}/build-bitstream.sh --cl_dir {cl_dir} --frequency {fpga_frequency} --strategy {build_strategy}"
            )
            vivado_rc = vivado_result.return_code

            if vivado_result != 0:
                rootLogger.info("Printing error output:")
                for line in vivado_result.splitlines()[-100:]:
                    rootLogger.info(line)

        # put build results in the result-build area

        rsync_cap = rsync_project(
            local_dir=f"{local_results_dir}/",
            remote_dir=cl_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            upload=False,
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        if vivado_rc != 0:
            on_build_failure()
            return False

        if not self.aws_create_afi():
            on_build_failure()
            return False

        build_farm.release_build_host(self.build_config)

        return True

    def aws_create_afi(self) -> Optional[bool]:
        """Convert the tarball created by Vivado build into an Amazon Global FPGA Image (AGFI).

        Args:
            build_config: Build config to determine paths.

        Returns:
            `True` on success, `None` on error.
        """
        local_deploy_dir = get_deploy_dir()
        local_results_dir = (
            f"{local_deploy_dir}/results-build/{self.build_config.get_build_dir_name()}"
        )

        afi = None
        agfi = None
        s3bucket = self.s3_bucketname
        afiname = self.build_config.name

        description = self.get_metadata_string()

        # if we're unlucky, multiple vivado builds may launch at the same time. so we
        # append the build node IP + a random string to diff them in s3
        global_append = (
            "-"
            + str(env.host_string)
            + "-"
            + "".join(
                random.SystemRandom().choice(string.ascii_uppercase + string.digits)
                for _ in range(10)
            )
            + ".tar"
        )

        with lcd(
            f"{local_results_dir}/cl_{self.build_config.get_chisel_quintuplet()}/build/checkpoints/"
        ):
            files = local("ls *.tar", capture=True)
            rootLogger.debug(files)
            rootLogger.debug(files.stderr)
            tarfile = files.split()[-1]
            s3_tarfile = tarfile + global_append
            localcap = local(
                "aws s3 cp " + tarfile + " s3://" + s3bucket + "/dcp/" + s3_tarfile,
                capture=True,
            )
            rootLogger.debug(localcap)
            rootLogger.debug(localcap.stderr)
            agfi_afi_ids = local(
                f"""aws ec2 create-fpga-image --input-storage-location Bucket={s3bucket},Key={"dcp/" + s3_tarfile} --logs-storage-location Bucket={s3bucket},Key={"logs/"} --name "{afiname}" --description "{description}" """,
                capture=True,
            )
            rootLogger.debug(agfi_afi_ids)
            rootLogger.debug(agfi_afi_ids.stderr)
            rootLogger.debug("create-fpge-image result: " + str(agfi_afi_ids))
            ids_as_dict = json.loads(agfi_afi_ids)
            agfi = ids_as_dict["FpgaImageGlobalId"]
            afi = ids_as_dict["FpgaImageId"]
            rootLogger.info("Resulting AGFI: " + str(agfi))
            rootLogger.info("Resulting AFI: " + str(afi))

        rootLogger.info("Waiting for create-fpga-image completion.")
        checkstate = "pending"
        with lcd(local_results_dir):
            while checkstate == "pending":
                imagestate = local(
                    f"aws ec2 describe-fpga-images --fpga-image-id {afi} | tee AGFI_INFO",
                    capture=True,
                )
                state_as_dict = json.loads(imagestate)
                checkstate = state_as_dict["FpgaImages"][0]["State"]["Code"]
                rootLogger.info("Current state: " + str(checkstate))
                time.sleep(10)

        if checkstate == "available":
            # copy the image to all regions for the current user
            copy_afi_to_all_regions(afi)

            message_title = "FireSim FPGA Build Completed"
            agfi_entry = afiname + ":\n"
            agfi_entry += "    agfi: " + agfi + "\n"
            agfi_entry += "    deploy_quintuplet_override: null\n"
            agfi_entry += "    custom_runtime_config: null\n"
            message_body = (
                "Your AGFI has been created!\nAdd\n\n"
                + agfi_entry
                + "\nto your config_hwdb.yaml to use this hardware configuration."
            )

            send_firesim_notification(message_title, message_body)

            rootLogger.info(message_title)
            rootLogger.info(message_body)

            # for convenience when generating a bunch of images. you can just
            # cat all the files in this directory after your builds finish to get
            # all the entries to copy into config_hwdb.yaml
            hwdb_entry_file_location = f"{local_deploy_dir}/built-hwdb-entries/"
            local("mkdir -p " + hwdb_entry_file_location)
            with open(hwdb_entry_file_location + "/" + afiname, "w") as outputfile:
                outputfile.write(agfi_entry)

            if self.build_config.post_build_hook:
                localcap = local(
                    f"{self.build_config.post_build_hook} {local_results_dir}",
                    capture=True,
                )
                rootLogger.debug("[localhost] " + str(localcap))
                rootLogger.debug("[localhost] " + str(localcap.stderr))

            rootLogger.info(
                f"Build complete! AFI ready. See {os.path.join(hwdb_entry_file_location,afiname)}."
            )
            return True
        else:
            return None

class VitisBitBuilder(BitBuilder):
    """Bit builder class that builds a Vitis bitstream from the build config.

    Attributes:
        device: vitis fpga platform string to use for building the bitstream
    """

    device: str

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self._parse_args()

    def _parse_args(self) -> None:
        """Parse bitbuilder arguments."""
        self.device = self.args["device"]

    def setup(self) -> None:
        return

    def cl_dir_setup(self, chisel_quintuplet: str, dest_build_dir: str) -> str:
        """Setup CL_DIR on build host.

        Args:
            chisel_quintuplet: Build config chisel quintuplet used to uniquely identify build dir.
            dest_build_dir: Destination base directory to use.

        Returns:
            Path to CL_DIR directory (that is setup) or `None` if invalid.
        """
        fpga_build_postfix = f"cl_{chisel_quintuplet}"

        # local paths
        local_vitis_dir = f"{get_deploy_dir()}/../platforms/vitis"

        dest_vitis_dir = "{}/platforms/vitis".format(dest_build_dir)

        # copy vitis to the build instance.
        # do the rsync, but ignore any checkpoints that might exist on this machine
        # (in case builds were run locally)
        # extra_opts -l preserves symlinks

        run("mkdir -p {}".format(dest_vitis_dir))
        run("rm -rf {}/{}".format(dest_vitis_dir, fpga_build_postfix))
        rsync_cap = rsync_project(
            local_dir=local_vitis_dir,
            remote_dir=dest_vitis_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            exclude="cl_*",
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)
        rsync_cap = rsync_project(
            local_dir="{}/{}/".format(local_vitis_dir, fpga_build_postfix),
            remote_dir="{}/{}".format(dest_vitis_dir, fpga_build_postfix),
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        return f"{dest_vitis_dir}/{fpga_build_postfix}"

    def build_bitstream(self, bypass: bool = False) -> bool:
        """Run Vitis to generate an xclbin. Then terminate the instance at the end.

        Args:
            bypass: If true, immediately return and terminate build host. Used for testing purposes.

        Returns:
            Boolean indicating if the build passed or failed.
        """
        build_farm = self.build_config.build_config_file.build_farm

        if bypass:
            build_farm.release_build_host(self.build_config)
            return True

        # The default error-handling procedure. Send an email and teardown instance
        def on_build_failure():
            """Terminate build host and notify user that build failed"""

            message_title = "FireSim Vitis FPGA Build Failed"

            message_body = (
                "Your FPGA build failed for quintuplet: "
                + self.build_config.get_chisel_quintuplet()
            )

            rootLogger.info(message_title)
            rootLogger.info(message_body)

            build_farm.release_build_host(self.build_config)

        rootLogger.info("Building Vitis Bitstream from Verilog")

        local_deploy_dir = get_deploy_dir()
        fpga_build_postfix = f"cl_{self.build_config.get_chisel_quintuplet()}"
        local_results_dir = (
            f"{local_deploy_dir}/results-build/{self.build_config.get_build_dir_name()}"
        )

        # 'cl_dir' holds the eventual directory in which vivado will run.
        cl_dir = self.cl_dir_setup(
            self.build_config.get_chisel_quintuplet(),
            build_farm.get_build_host(self.build_config).dest_build_dir,
        )

        vitis_rc = 0
        # copy script to the cl_dir and execute
        rsync_cap = rsync_project(
            local_dir=f"{local_deploy_dir}/../platforms/vitis/build-bitstream.sh",
            remote_dir=f"{cl_dir}/",
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        fpga_frequency = self.build_config.get_frequency()
        build_strategy = self.build_config.get_strategy().name

        with InfoStreamLogger("stdout"), settings(warn_only=True):
            vitis_result = run(
                f"{cl_dir}/build-bitstream.sh --build_dir {cl_dir} --device {self.device} --frequency {fpga_frequency} --strategy {build_strategy}"
            )
            vitis_rc = vitis_result.return_code

            if vitis_rc != 0:
                rootLogger.info("Printing error output:")
                for line in vitis_result.splitlines()[-100:]:
                    rootLogger.info(line)

        # put build results in the result-build area

        rsync_cap = rsync_project(
            local_dir=f"{local_results_dir}/",
            remote_dir=cl_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            upload=False,
            extra_opts="-l",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        if vitis_rc != 0:
            on_build_failure()
            return False

        hwdb_entry_name = self.build_config.name
        local_cl_dir = f"{local_results_dir}/{fpga_build_postfix}"

        bit_path = f"{local_cl_dir}/bitstream/build_dir.{self.device}/firesim.xclbin"
        tar_staging_path = f"{local_cl_dir}/{self.build_config.PLATFORM}"
        tar_name = "firesim.tar.gz"

        # store files into staging dir
        local(f"rm -rf {tar_staging_path}")
        local(f"mkdir -p {tar_staging_path}")

        # store bitfile
        local(f"cp {bit_path} {tar_staging_path}")

        # store metadata string
        local(f"""echo '{self.get_metadata_string()}' >> {tar_staging_path}/metadata""")

        # form tar.gz
        with prefix(f"cd {local_cl_dir}"):
            local(f"tar zcvf {tar_name} {self.build_config.PLATFORM}/")

        hwdb_entry = hwdb_entry_name + ":\n"
        hwdb_entry += f"    bitstream_tar: file://{local_cl_dir}/{tar_name}\n"
        hwdb_entry += f"    deploy_quintuplet_override: null\n"
        hwdb_entry += "    custom_runtime_config: null\n"

        message_title = "FireSim FPGA Build Completed"
        message_body = (
            "Your bitstream has been created!\nAdd\n\n"
            + hwdb_entry
            + "\nto your config_hwdb.yaml to use this hardware configuration."
        )

        rootLogger.info(message_title)
        rootLogger.info(message_body)

        # for convenience when generating a bunch of images. you can just
        # cat all the files in this directory after your builds finish to get
        # all the entries to copy into config_hwdb.yaml
        hwdb_entry_file_location = f"{local_deploy_dir}/built-hwdb-entries/"
        local("mkdir -p " + hwdb_entry_file_location)
        with open(hwdb_entry_file_location + "/" + hwdb_entry_name, "w") as outputfile:
            outputfile.write(hwdb_entry)

        if self.build_config.post_build_hook:
            localcap = local(
                f"{self.build_config.post_build_hook} {local_results_dir}", capture=True
            )
            rootLogger.debug("[localhost] " + str(localcap))
            rootLogger.debug("[localhost] " + str(localcap.stderr))

        rootLogger.info(
            f"Build complete! Vitis bitstream ready. See {os.path.join(hwdb_entry_file_location,hwdb_entry_name)}."
        )

        build_farm.release_build_host(self.build_config)

        return True


class XilinxAlveoBitBuilder(BitBuilder):
    """Bit builder class that builds a Xilinx Alveo bitstream from the build config."""

    BOARD_NAME: Optional[str]

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = None

    def setup(self) -> None:
        return

    def cl_dir_setup(self, chisel_quintuplet: str, dest_build_dir: str) -> str:
        """Setup CL_DIR on build host.

        Args:
            chisel_quintuplet: Build config chisel quintuplet used to uniquely identify build dir.
            dest_build_dir: Destination base directory to use.

        Returns:
            Path to CL_DIR directory (that is setup) or `None` if invalid.
        """
        fpga_build_postfix = f"cl_{chisel_quintuplet}"

        # local paths
        local_alveo_dir = (
            f"{get_deploy_dir()}/../platforms/{self.build_config.PLATFORM}"
        )

        dest_alveo_dir = f"{dest_build_dir}/platforms/{self.build_config.PLATFORM}"

        # copy alveo files to the build instance.
        # do the rsync, but ignore any checkpoints that might exist on this machine
        # (in case builds were run locally)
        # extra_opts -L resolves symlinks

        # On localhost, source and dest may resolve to the same directory.
        # Skip destructive rm-rf and rsync to avoid deleting our own source.
        local_resolved = os.path.realpath(local_alveo_dir)
        dest_resolved = os.path.realpath(dest_alveo_dir)
        if self._is_localhost() and local_resolved == dest_resolved:
            rootLogger.info(f"Localhost build: source and dest are same dir ({dest_resolved}), skipping rsync")
            cl_dir = f"{dest_alveo_dir}/{fpga_build_postfix}"
            if not os.path.exists(cl_dir):
                rootLogger.error(f"CL_DIR {cl_dir} does not exist!")
            return cl_dir

        self._exec(f"mkdir -p {dest_alveo_dir}")
        self._exec("rm -rf {}/{}".format(dest_alveo_dir, fpga_build_postfix))
        rsync_cap = self._rsync_files(
            local_dir=local_alveo_dir,
            remote_dir=dest_alveo_dir,
            exclude="cl_*",
            extra_opts="-L",
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)
        rsync_cap = self._rsync_files(
            local_dir=f"{local_alveo_dir}/{fpga_build_postfix}/",
            remote_dir=f"{dest_alveo_dir}/{fpga_build_postfix}",
            extra_opts="-L",
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        return f"{dest_alveo_dir}/{fpga_build_postfix}"

    def build_bitstream(self, bypass: bool = False) -> bool:
        """Run Vivado to generate an bit file. Then terminate the instance at the end.

        Args:
            bypass: If true, immediately return and terminate build host. Used for testing purposes.

        Returns:
            Boolean indicating if the build passed or failed.
        """
        build_farm = self.build_config.build_config_file.build_farm

        if bypass:
            build_farm.release_build_host(self.build_config)
            return True

        # The default error-handling procedure. Send an email and teardown instance
        def on_build_failure():
            """Terminate build host and notify user that build failed"""

            message_title = (
                f"FireSim Xilinx Alveo {self.build_config.PLATFORM} FPGA Build Failed"
            )

            message_body = (
                "Your FPGA build failed for quintuplet: "
                + self.build_config.get_chisel_quintuplet()
            )

            rootLogger.info(message_title)
            rootLogger.info(message_body)

            build_farm.release_build_host(self.build_config)

        rootLogger.info(
            f"Building Xilinx Alveo {self.build_config.PLATFORM} Bitstream from Verilog"
        )

        local_deploy_dir = get_deploy_dir()
        fpga_build_postfix = f"cl_{self.build_config.get_chisel_quintuplet()}"
        local_results_dir = (
            f"{local_deploy_dir}/results-build/{self.build_config.get_build_dir_name()}"
        )

        # 'cl_dir' holds the eventual directory in which vivado will run.
        cl_dir = self.cl_dir_setup(
            self.build_config.get_chisel_quintuplet(),
            build_farm.get_build_host(self.build_config).dest_build_dir,
        )

        alveo_rc = 0
        # copy script to the cl_dir and execute
        rsync_cap = self._rsync_files(
            local_dir=f"{local_deploy_dir}/../platforms/{self.build_config.PLATFORM}/build-bitstream.sh",
            remote_dir=f"{cl_dir}/",
            extra_opts="-L",
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        fpga_frequency = self.build_config.get_frequency()
        build_strategy = self.build_config.get_strategy().name

        with InfoStreamLogger("stdout"), settings(warn_only=True):
            alveo_result = self._exec(
                f"{cl_dir}/build-bitstream.sh --cl_dir {cl_dir} --frequency {fpga_frequency} --strategy {build_strategy} --board {self.BOARD_NAME}"
            )
            alveo_rc = alveo_result.return_code

            if alveo_rc != 0:
                rootLogger.info("Printing error output:")
                for line in alveo_result.splitlines()[-100:]:
                    rootLogger.info(line)

        # put build results in the result-build area

        rsync_cap = self._rsync_files(
            local_dir=f"{local_results_dir}/",
            remote_dir=cl_dir,
            upload=False,
            exclude=["verif", "xsim", "vcs", "stamp"],
            extra_opts="-l --safe-links",
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        if alveo_rc != 0:
            on_build_failure()
            return False

        # make hwdb entry from locally stored results

        hwdb_entry_name = self.build_config.name
        local_cl_dir = f"{local_results_dir}/{fpga_build_postfix}"
        bit_path = f"{local_cl_dir}/vivado_proj/firesim.bit"
        mcs_path = f"{local_cl_dir}/vivado_proj/firesim.mcs"
        mcs_secondary_path = f"{local_cl_dir}/vivado_proj/firesim_secondary.mcs"
        tar_staging_path = f"{local_cl_dir}/{self.build_config.PLATFORM}"
        tar_name = "firesim.tar.gz"

        # store files into staging dir
        local(f"rm -rf {tar_staging_path}")
        local(f"mkdir -p {tar_staging_path}")

        # store bitfile (and mcs if it exists)
        local(f"cp {bit_path} {tar_staging_path}")
        local(f"cp {mcs_path} {tar_staging_path}")
        if self.build_config.PLATFORM == "xilinx_vcu118":
            local(f"cp {mcs_secondary_path} {tar_staging_path}")

        # store metadata string
        local(f"""echo '{self.get_metadata_string()}' >> {tar_staging_path}/metadata""")

        # form tar.gz
        with prefix(f"cd {local_cl_dir}"):
            local(f"tar zcvf {tar_name} {self.build_config.PLATFORM}/")

        hwdb_entry = hwdb_entry_name + ":\n"
        hwdb_entry += f"    bitstream_tar: file://{local_cl_dir}/{tar_name}\n"
        hwdb_entry += f"    deploy_quintuplet_override: null\n"
        hwdb_entry += "    custom_runtime_config: null\n"

        message_title = "FireSim FPGA Build Completed"
        message_body = f"Your bitstream has been created!\nAdd\n\n{hwdb_entry}\nto your config_hwdb.yaml to use this hardware configuration."

        rootLogger.info(message_title)
        rootLogger.info(message_body)

        # for convenience when generating a bunch of images. you can just
        # cat all the files in this directory after your builds finish to get
        # all the entries to copy into config_hwdb.yaml
        hwdb_entry_file_location = f"{local_deploy_dir}/built-hwdb-entries/"
        local("mkdir -p " + hwdb_entry_file_location)
        with open(hwdb_entry_file_location + "/" + hwdb_entry_name, "w") as outputfile:
            outputfile.write(hwdb_entry)

        if self.build_config.post_build_hook:
            localcap = local(
                f"{self.build_config.post_build_hook} {local_results_dir}", capture=True
            )
            rootLogger.debug("[localhost] " + str(localcap))
            rootLogger.debug("[localhost] " + str(localcap.stderr))

        rootLogger.info(
            f"Build complete! Xilinx Alveo {self.build_config.PLATFORM} bitstream ready. See {os.path.join(hwdb_entry_file_location,hwdb_entry_name)}."
        )

        build_farm.release_build_host(self.build_config)

        return True


class XilinxAlveoU200BitBuilder(XilinxAlveoBitBuilder):
    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "au200"


class XilinxAlveoU280BitBuilder(XilinxAlveoBitBuilder):
    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "au280"


class XilinxAlveoU250BitBuilder(XilinxAlveoBitBuilder):
    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "au250"


class CorigineXB10BitBuilder(XilinxAlveoBitBuilder):
    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "xb10"


class XilinxAlveoV80BitBuilder(XilinxAlveoBitBuilder):
    """V80 Versal ACAP (QDMA, PDI output)."""
    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "v80"


class XilinxVCU118BitBuilder(XilinxAlveoBitBuilder):
    """Bit builder class that builds a Xilinx VCU118 bitstream from the build config."""

    BOARD_NAME: Optional[str]

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "xilinx_vcu118"

    def cl_dir_setup(self, chisel_quintuplet: str, dest_build_dir: str) -> str:
        """Setup CL_DIR on build host.

        Args:
            chisel_quintuplet: Build config chisel quintuplet used to uniquely identify build dir.
            dest_build_dir: Destination base directory to use.

        Returns:
            Path to CL_DIR directory (that is setup) or `None` if invalid.
        """
        fpga_build_postfix = f"cl_{chisel_quintuplet}"

        # local paths
        local_alveo_dir = f"{get_deploy_dir()}/../platforms/{self.build_config.PLATFORM}/garnet-firesim"

        dest_alveo_dir = (
            f"{dest_build_dir}/platforms/{self.build_config.PLATFORM}/garnet-firesim"
        )

        # copy alveo files to the build instance.
        # do the rsync, but ignore any checkpoints that might exist on this machine
        # (in case builds were run locally)
        # extra_opts -L resolves symlinks

        run(f"mkdir -p {dest_alveo_dir}")
        run("rm -rf {}/{}".format(dest_alveo_dir, fpga_build_postfix))
        rsync_cap = rsync_project(
            local_dir=local_alveo_dir + "/",
            remote_dir=dest_alveo_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            exclude="cl_*",
            extra_opts="-L",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)
        rsync_cap = rsync_project(
            local_dir=f"{local_alveo_dir}/{fpga_build_postfix}/",
            remote_dir=f"{dest_alveo_dir}/{fpga_build_postfix}",
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-L",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        return f"{dest_alveo_dir}/{fpga_build_postfix}"


class RHSResearchNitefuryIIBitBuilder(XilinxAlveoBitBuilder):
    """Bit builder class that builds an RHS Research Nitefury II bitstream from the build config."""

    BOARD_NAME: Optional[str]

    def __init__(self, build_config: BuildConfig, args: Dict[str, Any]) -> None:
        super().__init__(build_config, args)
        self.BOARD_NAME = "rhsresearch_nitefury_ii"

    def cl_dir_setup(self, chisel_quintuplet: str, dest_build_dir: str) -> str:
        """Setup CL_DIR on build host.

        Args:
            chisel_quintuplet: Build config chisel quintuplet used to uniquely identify build dir.
            dest_build_dir: Destination base directory to use.

        Returns:
            Path to CL_DIR directory (that is setup) or `None` if invalid.
        """
        fpga_build_postfix = f"Sample-Projects/Project-0/cl_{chisel_quintuplet}"

        # local paths
        local_alveo_dir = f"{get_deploy_dir()}/../platforms/{self.build_config.PLATFORM}/NiteFury-and-LiteFury-firesim"

        dest_alveo_dir = f"{dest_build_dir}/platforms/{self.build_config.PLATFORM}/NiteFury-and-LiteFury-firesim"

        # copy alveo files to the build instance.
        # do the rsync, but ignore any checkpoints that might exist on this machine
        # (in case builds were run locally)
        # extra_opts -L resolves symlinks

        run(f"mkdir -p {dest_alveo_dir}")
        run("rm -rf {}/{}".format(dest_alveo_dir, fpga_build_postfix))
        rsync_cap = rsync_project(
            local_dir=local_alveo_dir + "/",
            remote_dir=dest_alveo_dir,
            ssh_opts="-o StrictHostKeyChecking=no",
            exclude="cl_*",
            extra_opts="-L",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)
        rsync_cap = rsync_project(
            local_dir=f"{local_alveo_dir}/{fpga_build_postfix}/",
            remote_dir=f"{dest_alveo_dir}/{fpga_build_postfix}",
            ssh_opts="-o StrictHostKeyChecking=no",
            extra_opts="-L",
            capture=True,
        )
        rootLogger.debug(rsync_cap)
        rootLogger.debug(rsync_cap.stderr)

        return f"{dest_alveo_dir}/{fpga_build_postfix}"
