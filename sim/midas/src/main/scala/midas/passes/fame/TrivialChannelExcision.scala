// See LICENSE for license details.

package midas.passes.fame

import firrtl._
import ir._
import traversals.Foreachers._
import annotations.{ModuleTarget, ReferenceTarget}
import analyses.InstanceGraph
import collection.mutable

/*
 * Trivial Channel Excision
 * This pass does what channel excision would do for the trivial case
 * of one model in low FIRRTL
 */

class TrivialChannelExcision extends Transform {
  def inputForm  = LowForm
  def outputForm = LowForm

  override def execute(state: CircuitState): CircuitState = {
    val topName          = state.circuit.main
    val topModule        = state.circuit.modules
      .find(_.name == topName)
      .collect({ case m: Module =>
        m
      })
      .get
    val topChildren      = new mutable.HashSet[WDefInstance]
    topModule.body.foreach(InstanceGraph.collectInstances(topChildren))
    assert(topChildren.size == 1)
    val specialSignals   = state.annotations
      .collect({
        case FAMEHostClock(rt) => rt.ref
        case FAMEHostReset(rt) => rt.ref
      })
      .toSet
    val fame1Anno        = FAMETransformAnnotation(ModuleTarget(topName, topChildren.head.module))
    val fameChannelAnnos = topModule.ports.collect({
      case Port(_, name, Input, _) if !specialSignals.contains(name) =>
        FAMEChannelConnectionAnnotation
          .implicitlyClockedSink(name, WireChannel, Seq(ReferenceTarget(topName, topName, Nil, name, Nil)))
      case Port(_, name, Output, _)                                  =>
        FAMEChannelConnectionAnnotation.implicitlyClockedSource(
          name,
          WireChannel,
          Seq(ReferenceTarget(topName, topName, Nil, name, Nil)),
        )
    })
    state.copy(annotations = state.annotations ++ Seq(fame1Anno) ++ fameChannelAnnos)
  }
}
