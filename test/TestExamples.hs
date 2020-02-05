{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
module TestExamples where

import Prelude hiding (getLine, putStrLn, print)

import Test.IOTest.IOrep
import qualified Test.IOTest.IOProperty as IOP
import Test.IOTest.Translation
import Test.IOTest.TraceSet
import Test.IOTest.Examples.Examples
import Test.IOTest.Trace
import Test.IOTest.Language
import Test.IOTest.Term

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

import Control.DeepSeq
import GHC.Generics

import qualified SpecGen

specGen :: Gen Specification
specGen = SpecGen.specGen

loopBodyGen :: Gen Specification
loopBodyGen = SpecGen.loopBodyGen

fulfills :: IOrep () -> Specification -> Property
fulfills = IOP.fulfills

testExamples :: Spec
testExamples = describe "Testing Test.IOTest.Examples.Examples:" $ do
  prop "solution1 matches task1" $
    solution1 `fulfills` task1
  prop "solution1' does not match task1" $
    expectFailure $ solution1' `fulfills` task1
  prop "wrongSolution1 does not match task1" $
    expectFailure $ wrongSolution1 `fulfills` task1
  prop "solution1 matches task1'" $
    solution1 `fulfills` task1'

  prop "solution1' matches task1'" $
    solution1' `fulfills` task1'
  prop "solution2 matches task2" $
   solution2 `fulfills` task2
  prop "solution3 matches task3" $
    solution3 `fulfills` task3
  prop "solution3 matches task3'" $
    solution3 `fulfills` task3'

  prop "program generated from task1 matches task1" $
    buildComputation @IOrep task1 `fulfills` task1
  prop "program generated from task1' matches task1'" $
    buildComputation @IOrep task1' `fulfills` task1'
  prop "program generated from task2 matches task2" $
    buildComputation @IOrep task2 `fulfills` task2
  prop "program generated from task3 matches task3" $
    buildComputation @IOrep task3 `fulfills` task3
  prop "program generated from task3' matches task3'" $
    buildComputation @IOrep task3' `fulfills` task3'

  prop "Testing solution4 against task4" $
    solution4 `fulfills` task4
  prop "Testing wrongsolution4 against task4" $
    expectFailure $ wrongSolution4 `fulfills` task4

  prop "correct handeling of scoping 1" $
    scopingRight `fulfills` scoping
  prop "correct handeling of scoping 2" $
    expectFailure $ scopingWrong `fulfills` scoping

  -- prop "multi parameter programs" $
  --   printN `fulfills` printNSpec

  prop "programs built from a spec satisfy that spec" $
    forAll specGen (\s -> buildComputation @IOrep s `fulfills` s)

  prop "programs built from a spec do not always satisfy that spec if they implement branches in 'reverse'" $
    forAll specGen (\s ->
      let prog = buildWrongComputation @IOrep s
      in  expectFailure $ prog `fulfills` s)

  prop "programs built from a spec dont go wrong on inputs generated from the same spec" $
    forAll specGen (\s ->
      forAll (traceGen s) (\t ->
        let is = inputsN t
        in runProgram is (buildComputation @IOrep s) `deepseq` True
    ))

  prop "relate traceGen and accept" $
    forAll specGen (\s -> forAll (traceGen s) (\t' -> forAll (sampleNTrace t') (IOP.accept s)))

  -- currently not working: triggers "Prelude.read: no parse" in buildComputation
  -- prop "inputs are never optional for a fixed input prefix" $
  --   forAll specGen (\s ->
  --     forAll (traceGen s) (\t ->
  --       let is = inputsN t
  --       in not (null is) ==> fulfillsNotFor (init is) (buildComputation @IOrep s) s))

  prop "tillExit s === tillExit (s <> tillExit s <> exit) " $
    forAll loopBodyGen $ \s -> testEquiv
      (tillExit s)
      (tillExit (s <> tillExit s <> exit))

  prop "s1 <> (s2 <> s3) === (s1 <> s2) <> s3" $
    forAll ((,,) <$> specGen <*> specGen <*> specGen) $
      \(s1,s2,s3) -> testEquiv
        (s1 <> (s2 <> s3))
        ((s1 <> s2) <> s3)

  prop "tillExit (s1 <> exit) === tillExit (s1 <> exit <> s2)" $
    forAll ((,) <$> specGen <*> specGen) $
      \(s1,s2) -> testEquiv
        (tillExit (s1 <> exit))
        (tillExit (s1 <> exit <> s2))

testEquiv :: Specification -> Specification -> Property
testEquiv s1 s2 = p1 .&&. p2 where
  p1 = s1 `testAgainst` s2
  p2 = s2 `testAgainst` s1
  testAgainst x y =
    forAll (traceGen x) (\t ->
      forAll (sampleNTrace t) (IOP.accept y))

deriving instance Generic (Trace a)
deriving instance NFData a => NFData (Trace a)
