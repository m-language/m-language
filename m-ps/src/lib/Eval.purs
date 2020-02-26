module Eval where

import Control.Monad.Except (ExceptT, catchError, throwError)
import Control.Monad.Trampoline (Trampoline)
import Control.Monad.Reader (ReaderT, ask)
import Data.Array as Array
import Data.BigInt (BigInt, toString)
import Data.List (List(..), drop, length, null, take, (:))
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set (Set)
import Data.Set as Set
import Data.String.Common (joinWith)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..), snd)
import Effect (Effect)
import Prelude (class Monoid, class Semigroup, class Show, append, bind, map, mempty, otherwise, pure, show, ($), (-), (<), (<<<), (<>), (>), (>>=))
import Tree (Tree(..))

data Process
  = Impure (Effect Value)
  | Do Process (Value -> EvalResult Process)

data Value
  = Function Int (Env -> List (EvalResult Value) -> EvalResult Value)
  | Macro Int (Env -> List Tree -> EvalResult Value)
  | Define Env
  | Expr Tree
  | CharValue Char
  | StringValue String
  | IntValue BigInt
  | ProcessValue Process

data Error
  = Error String
  | Undefined (Set String)

instance showValue :: Show Value where
  show (Function n f) = "<function>"
  show (Macro n f) = "<macro>"
  show (Expr t) = "'" <> show t
  show (CharValue c) = show c
  show (StringValue s) = show s
  show (IntValue i) = toString i
  show (Define (Env e)) = "{" <> (joinWith " " (Array.fromFoldable (Map.keys e))) <> "}"
  show (ProcessValue p) = "<process>"

instance showError :: Show Error where
  show (Error string) = "Error: " <> string
  show (Undefined ns) = "Undefined: " <> (joinWith " " (Array.fromFoldable ns))

newtype Env
  = Env (Map String (EvalResult Value))

instance envMonoid :: Monoid Env where
  mempty = Env mempty

instance envSemigroup :: Semigroup Env where
  append (Env a) (Env b) = Env (append a b)

insertEnv :: String -> Value -> Env -> Env
insertEnv name value (Env env) = Env $ Map.insert name (pure value) env

unionEnv :: Env -> Env -> Env
unionEnv (Env a) (Env b) = Env $ Map.union a b

insertEnvLazy :: String -> EvalResult Value -> Env -> Env
insertEnvLazy name value (Env env) = Env $ Map.insert name value env

lookupEnv :: String -> Env -> Maybe (EvalResult Value)
lookupEnv name (Env env) = Map.lookup name env

type EvalResult = ReaderT Env (ExceptT Error Trampoline)

evalBlock :: Env -> List Tree -> EvalResult Env
evalBlock env = evalBlock' env false Set.empty Nil

evalBlock' :: Env -> Boolean -> Set String -> List Tree -> List Tree -> EvalResult Env
evalBlock' env found errors Nil Nil = pure $ Env Map.empty
evalBlock' env true errors defer Nil = evalBlock' env false Set.empty Nil defer
evalBlock' env false errors defer Nil = throwError $ Undefined errors
evalBlock' env found errors defer (car : cdr) =
  let
    result = do
      defs <- asDefine $ eval (Tuple env car)
      defs' <- evalBlock' (unionEnv defs env) true errors defer cdr
      pure $ unionEnv defs defs'
  in
    catchError result \x -> case x of
      Undefined names -> evalBlock' env found (Set.union names errors) (car : defer) cdr
      Error string -> throwError $ Error string

eval :: Tuple Env Tree -> EvalResult Value
eval (Tuple env (SymbolTree name)) = case lookupEnv name env of
  Just value -> value
  Nothing -> do
    globals <- ask
    case lookupEnv name globals of
      Just value -> value
      Nothing -> throwError $ Undefined $ Set.singleton name
eval (Tuple env (IntTree integer)) = pure $ IntValue integer
eval (Tuple env (CharTree char)) = pure $ CharValue char
eval (Tuple env (StringTree string)) = pure $ StringValue string
eval (Tuple env (ApplyTree Nil)) = pure nil
eval (Tuple env (ApplyTree (fn : args))) = do
  f <- eval (Tuple env fn)
  apply env f $ map (Tuple env) args

asDefine :: EvalResult Value -> EvalResult Env
asDefine tree = tree >>= \x -> case x of
  (Define defs) -> pure defs
  err -> throwError $ Error $ "Expected expression, found " <> show err

asExpr :: EvalResult Value -> EvalResult Tree
asExpr tree = tree >>= \x -> case x of
  (Expr t) -> pure t
  err -> throwError $ Error $ "Expected expression, found " <> show err

asSymbol :: EvalResult Value -> EvalResult String
asSymbol tree = asExpr tree >>= \x -> case x of
  (SymbolTree s) -> pure s
  err -> throwError $ Error $ "Expected symbol, found " <> show err

asChar :: EvalResult Value -> EvalResult Char
asChar tree = tree >>= \x -> case x of
  (CharValue char) -> pure char
  err -> throwError $ Error $ "Expected character, found " <> show err

asString :: EvalResult Value -> EvalResult String
asString tree = tree >>= \x -> case x of
  (StringValue string) -> pure string
  err -> throwError $ Error $ "Expected string, found " <> show err

asInteger :: EvalResult Value -> EvalResult BigInt
asInteger tree = tree >>= \x -> case x of
  (IntValue i) -> pure i
  err -> throwError $ Error $ "Expected integer, found " <> show err

asProcess :: EvalResult Value -> EvalResult Process
asProcess tree = tree >>= \x -> case x of
  (ProcessValue p) -> pure p
  err -> throwError $ Error $ "Expected process, found " <> show err

apply :: Env -> Value -> List (Tuple Env Tree) -> EvalResult Value
apply env (Macro n f) args
  | length args < n = 
      pure $ Macro (n - length args) \env' args' ->
          apply env' (Macro n f) (args <> map (Tuple env') args')
  | length args > n = 
      apply env (Macro n f) (take n args) 
          >>= \v -> apply env v (drop n args)
  | otherwise = f env $ map snd args
apply env (Define defs) args =
  apply env
    ( Macro 1 \env' exprs -> case exprs of
        expr : Nil -> eval (Tuple (unionEnv env' defs) expr)
        _ -> throwError $ Error $ "Impossible"
    )
    args
apply env (Expr tree) args = do
  evArgs <- traverse (asExpr <<< eval) args
  pure $ Expr $ if null evArgs then tree else ApplyTree $ tree : evArgs
apply env x args = applyFn env x $ map eval args

applyFn :: Env -> Value -> List (EvalResult Value) -> EvalResult Value
applyFn env (Function n f) args
  | length args < n = 
      pure $ Function (n - length args) \env' args' ->
          applyFn env' (Function n f) (args <> args')
  | length args > n =
      applyFn env (Function n f) (take n args)
          >>= \v -> applyFn env v (drop n args)
  | otherwise = f env args
applyFn env x args = throwError $ Error $ "Expected function, found " <> show x

nil :: Value
nil = Expr $ ApplyTree Nil