// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import org.junit.Assert.*
import org.junit.Test
class ScreenIntervalsTest {
 @Test fun lockedAndScreenOffDoNotCount() {
  val r=ScreenIntervals.count(0,5000,true,true,listOf(1000L to 16,3000L to 15,3000L to 17,4000L to 18))
  assertEquals(2000L,r.used)
 }
 @Test fun duplicateBoundaryEventsDoNotDoubleCount() {
  val r=ScreenIntervals.count(1000,3000,false,true,listOf(1000L to 15,1000L to 15,2000L to 16))
  assertEquals(1000L,r.used)
 }
 @Test fun unrelatedAndOutOfRangeEventsIgnored() {
  assertEquals(1000L,ScreenIntervals.count(1000,2000,true,true,listOf(0L to 16,1500L to 1,3000L to 16)).used)
 }
 @Test fun lockedVideoDoesNotCountButUnlockedVideoDoes() {
  assertEquals(0L,ScreenIntervals.count(0,1000,true,false,emptyList()).used)
  assertEquals(1000L,ScreenIntervals.count(0,1000,true,true,emptyList()).used)
 }

 @Test fun shortOffPreservesAccumulation() {
  val r=ScreenIntervals.withReset(0,20000,true,true,listOf(5000L to 16,15000L to 15),60000,60000,30000,-1)
  assertEquals(50000L,r.remaining)
 }
 @Test fun exactThresholdResetsBeforeUnlockCounting() {
  val r=ScreenIntervals.withReset(0,40000,true,true,listOf(5000L to 16,35000L to 15),20000,60000,30000,-1)
  assertEquals(55000L,r.remaining)
 }
 @Test fun offAcrossPollsResetsWithoutCredit() {
  val a=ScreenIntervals.withReset(0,20000,true,true,listOf(5000L to 16),20000,60000,30000,-1)
  val b=ScreenIntervals.withReset(20000,36000,a.on,a.unlocked,emptyList(),a.remaining,60000,30000,a.offSince)
  assertEquals(60000L,b.remaining)
 }
 @Test fun lockedButScreenOnDoesNotReset() {
  val r=ScreenIntervals.withReset(0,40000,true,false,emptyList(),20000,60000,30000,-1)
  assertEquals(20000L,r.remaining)
 }
 @Test fun breakLengthCanBeResetThreshold() {
  val r=ScreenIntervals.withReset(0,120000,false,true,emptyList(),20000,60000,120000,0)
  assertEquals(60000L,r.remaining)
 }
}
