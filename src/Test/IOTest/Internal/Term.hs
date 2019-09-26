{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilyDependencies #-}
module Test.IOTest.Internal.Term (
  Term,
  --update,
  getCurrent,
  getAll,
  evalTerm,
) where

import Test.IOTest.Internal.Environment
import Test.IOTest.Utils

import Data.Functor.Identity (Identity(..))
import Control.Monad.Reader
import Control.Monad.Trans.Maybe

import Data.Maybe
import Data.Dynamic
import Data.Proxy

newtype Term a = Term { getTerm :: Environment -> Maybe a }
  deriving (Functor, Applicative) via (MaybeT (Reader Environment))

evalTerm :: Term a -> Environment -> a
evalTerm t = fromMaybe (error "Can not evaluate epsilon!") . getTerm t

--TODO: What is this good for? Janis: I don't think for anything.
-- update :: Eq v => v -> s -> Term ()
-- update x v = Term $ Just <$> modify (map (x `addValue` v))
--   where
--     addValue x' v' (y,vs') = if y == x' then (y,vs' ++ [v']) else (y,vs')

epsilon :: Term a
epsilon = Term $ return Nothing

isEpsilon :: Term a -> Bool
isEpsilon t = isNothing $ getTerm t []

getCurrent :: forall s a . (Typeable a, StringEmbedding s a) => Proxy s -> Varname -> Term a
getCurrent p x =
  let vs = getAll p x
  in if isJust $ getTerm vs []
    then last <$> vs
    else error $ "getCurrent: no values stored for " <> x

getAll :: forall s a . (Typeable a, StringEmbedding s a) => Proxy s -> Varname -> Term [a]
getAll p x = Term $ Just <$> do
  mVs <- reader $ lookupNameAtType p x
  case mVs of
    Left e -> error $ printLookupError e
    Right vs -> return vs
