{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
module Test.IOTest.TraceSet (
  traceGen
) where

import Prelude hiding (putStrLn, getLine)

import Test.IOTest.IOrep
import Test.IOTest.Semantics
import Test.IOTest.Trace
import Test.IOTest.Pattern
import Test.IOTest.Environment
import Test.IOTest.ValueSet
import Test.IOTest.Specification

-- import Test.QuickCheck hiding (Positive,Function)
import Test.QuickCheck.GenT
import qualified Data.Set as S
import           Data.Maybe

import System.Random

import Control.Monad.State
import Control.Monad.Writer

traceGen :: MonadGen m => Specification -> m GeneralizedNTrace
traceGen s = do
  (loopStatus, t) <- runWriterT $ evalSemantics (traceGen' s) (freshEnvironment s)
  case loopStatus of
    Right () -> return t
    Left Exit -> error "traceGen: 'throwError Exit' at toplevel"

traceGen' :: (MonadGen m, MonadWriter GeneralizedNTrace m) => Specification -> Semantics m ()
traceGen' = interpret genRead genWrite

genRead :: (MonadGen m, MonadWriter GeneralizedNTrace m) => Action -> Semantics m ()
genRead (ReadInput x vs) = sized $ \size -> do
  seed <- choose (minBound, maxBound)
  let val = valueOf vs (mkStdGen seed)
  modify (fromMaybe (error "type mismatch on environment update") . updateWithValue x val)
  tell $ progReadN (show val)
  -- FIXME: clean up according to paper definition?
genRead _ = error "genRead"

genWrite :: (MonadGen m, MonadWriter GeneralizedNTrace m) => Action -> Semantics m ()
genWrite (WriteOutput opt ps ts) = sized $ \size -> do
  d <- get
  let v1 = S.fromList ((\p -> fillHoles (p,ts) d) <$> ps)
      v1' = if opt then S.insert emptyPattern v1 else v1
  unless (null v1') $ tell (progWriteN v1')
genWrite _ = error "genWrite"
