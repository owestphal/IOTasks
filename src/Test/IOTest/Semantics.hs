{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Test.IOTest.Semantics (
  Semantics(..),
  evalSemantics,
  interpret,
  ) where

import Prelude hiding (foldMap)

import Test.IOTest.IOrep
import Test.IOTest.Environment
import Test.IOTest.Specification
import Test.IOTest.Trace
import Test.IOTest.Term

import Control.Monad.Extra (ifM)
import Control.Monad.State
import Control.Monad.Writer
import Control.Monad.Except

import Data.Coerce ( coerce )
import Data.MonoTraversable.Unprefixed

import Test.QuickCheck.GenT

newtype Semantics m a = Semantics { runSemantics :: Environment -> m (Either Exit a, Environment) }
  deriving (Functor, Applicative, Monad, MonadTeletype, MonadState Environment, MonadError Exit, MonadGen) via ExceptT Exit (StateT Environment m)

evalSemantics :: Monad m => Semantics m a -> Environment -> m (Either Exit a)
evalSemantics m c = fst <$> runSemantics m c

execSemantics :: Monad m => Semantics m a -> Environment -> m Environment
execSemantics m c = snd <$> runSemantics m c

mapSemantics :: (m (Either Exit a, Environment) -> n (Either Exit b, Environment)) -> Semantics m a -> Semantics n b
mapSemantics f (Semantics g) = Semantics (f . g)

withSemantics :: (Environment -> Environment) -> Semantics m a -> Semantics m a
withSemantics f (Semantics g) = Semantics (g . f)

instance MonadWriter GeneralizedTrace m  => MonadWriter GeneralizedTrace (Semantics m) where
  writer = coerce . writer @GeneralizedTrace @(ExceptT Exit (StateT Environment m))
  tell = coerce . tell @GeneralizedTrace @(ExceptT Exit (StateT Environment m))
  listen = listen . coerce
  pass = pass . coerce

instance Monad m => Semigroup (Semantics m ()) where
  (<>) = (>>)

instance Monad m => Monoid (Semantics m ()) where
  mempty = return ()

interpret ::
     (Monad m)
  => (Action -> Semantics m ()) -- handle read
  -> (Action -> Semantics m ()) -- handle write
  -> Specification -- specification
  -> Semantics m ()
interpret r w = foldMap (interpret' r w)

interpret' ::
     (Monad m)
  => (Action -> Semantics m ()) -- handle read
  -> (Action -> Semantics m ()) -- handle write
  -> Action -- action
  -> Semantics m ()
interpret' r _ act@ReadInput{} = r act
interpret' _ w act@WriteOutput{} = w act
interpret' r w (TillE s) =
  let body = interpret r w s
      loop = forever body -- repeat until the loop is terminated by an exit marker
  in catchError loop (\Exit -> return ())
interpret' r w (Branch c s1 s2) =
  ifM (gets (evalTerm c))
    (interpret r w s2)
    (interpret r w s1)
interpret' _ _ E = throwError Exit

-- orphan instances

instance MonadGen m => MonadGen (StateT s m) where
  liftGen g = lift $ liftGen g
  variant n = mapStateT (variant n)
  sized f = let g s = sized (\n -> runStateT (f n) s) in StateT g
  resize n = mapStateT (resize n)
  choose p = lift $ choose p

instance (MonadGen m, Monoid w) => MonadGen (WriterT w m) where
  liftGen g = lift $ liftGen g
  variant n = mapWriterT (variant n)
  sized f = let g = sized (runWriterT . f) in WriterT g
  resize n = mapWriterT (resize n)
  choose p = lift $ choose p

instance MonadGen m => MonadGen (ExceptT Exit m) where
  liftGen g = lift $ liftGen g
  variant n = mapExceptT (variant n)
  sized f = let g = sized (runExceptT . f) in ExceptT g
  resize n = mapExceptT (resize n)
  choose p = lift $ choose p
