{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE MonoLocalBinds #-}
module Test.IOTasks.Language
  ( Specification, readInput, writeOutput, branch, tillExit, nop, exit
  , writeFixedOutput
  , Varname, Term, optional
  , getCurrent, getAll
  , Pattern, buildPattern
  , TermPattern, buildTermPattern
  , ValueSet
  , intValues
  , values
  , stringValues
  , mkValueSet
  , ints
  , nats
  , StringEmbedding
  ) where

import Data.Dynamic (Typeable)

import Test.IOTasks.Utils
import Test.IOTasks.Specification
import Test.IOTasks.Term
import Test.IOTasks.Environment (Varname)
import Test.IOTasks.ValueSet
import Test.IOTasks.Pattern

import Test.QuickCheck (Gen, Arbitrary, elements)


readInput :: Varname -> ValueSet -> Specification t
readInput x vs = Spec [ReadInput x vs]

writeOutput :: StringEmbedding a => [TermPattern] -> [t a] -> Specification t
writeOutput ps ts = Spec [WriteOutput False ps ts]

writeFixedOutput :: [TermPattern] -> Specification t
writeFixedOutput ps = Spec [WriteOutput False ps ([] :: [t String])]

branch :: t Bool -> Specification t -> Specification t -> Specification t
branch t s1 s2 = Spec [Branch t s1 s2]

tillExit :: Specification t -> Specification t
tillExit s = Spec [TillE s]

nop :: Specification t
nop = mempty

exit :: Specification t
exit = Spec [E]

intValues :: [Int] -> ValueSet
intValues = valueSet

values :: (Typeable a, Arbitrary a, StringEmbedding a, Eq a) => [a] -> ValueSet
values = valueSet

stringValues :: Pattern -> ValueSet
stringValues = valueSet

ints :: ValueSet
ints = valueSet' (const True) gen where
  gen :: Gen Int
  gen = elements [-10..10]

nats :: ValueSet
nats = valueSet' (>= 0) gen where
  gen :: Gen Int
  gen = elements [0..10]

mkValueSet :: (Typeable a, Arbitrary a, StringEmbedding a) => (a -> Bool) -> Gen a -> ValueSet
mkValueSet = valueSet'
