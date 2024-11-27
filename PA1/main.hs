import PA1Helper
import System.Environment (getArgs)
import qualified Data.Set as DS

-- Find the free variables in a lambda expression
findFreeVars :: Lexp -> DS.Set String
findFreeVars (Atom var) = DS.singleton var
findFreeVars (Lambda var expr) = DS.delete var (findFreeVars expr)
findFreeVars (Apply expr1 expr2) = DS.union (findFreeVars expr1) (findFreeVars expr2)

-- Generate a unique variable that is not in the set of used variables
getNewVar :: String -> DS.Set String -> String
getNewVar var used =
  if DS.notMember var used 
  then var
  else generateNewVar var used

generateNewVar :: String -> DS.Set String -> String
generateNewVar var used =
  let possibleVars = "z" : [var++ show num | num<-[1..]]
      unusedVars = filter (`DS.notMember` used) possibleVars
  in head unusedVars

-- Replace variable var with expr and make sure to avoid variable capture
replaceVar :: String -> Lexp -> Lexp -> Lexp
replaceVar var expr' (Atom name)
  |var == name = expr'
  |otherwise = Atom name
replaceVar var expr' (Lambda param body)
  |param == var = Lambda param body
  |param `DS.member` findFreeVars expr' =
      let allVars = DS.union (findFreeVars body) (findFreeVars expr')
          param' = getNewVar param allVars
          newBody = replaceVar param (Atom param') body
      in Lambda param' (replaceVar var expr' newBody)
  | otherwise = Lambda param (replaceVar var expr' body)
replaceVar var expr' (Apply expr1 expr2) =
  Apply (replaceVar var expr' expr1) (replaceVar var expr' expr2)

-- Do beta reduction recursively
betaReduction :: Lexp -> Lexp
betaReduction (Apply (Lambda var body) expr2) =
  betaReduction (replaceVar var expr2 body)
betaReduction (Apply expr1 expr2) =
  let reducedExpr1 = betaReduction expr1
      reducedExpr2 = betaReduction expr2
  in Apply reducedExpr1 reducedExpr2
betaReduction (Lambda var body) =
  Lambda var (betaReduction body)
betaReduction expr = expr

-- Do eta reduction recursively
etaReduction :: Lexp -> Lexp
etaReduction (Lambda var (Apply expr (Atom name))) 
  | var == name && not (DS.member var (findFreeVars expr)) =
      etaReduction expr
etaReduction (Lambda var body) =
  Lambda var (etaReduction body)
etaReduction (Apply expr1 expr2) =
  Apply (etaReduction expr1) (etaReduction expr2)
etaReduction expr = expr

-- Repeatedly apply beta and eta reductions until impossible
performReduction :: Lexp -> Lexp
performReduction expr =
  let betaReduced = betaReduction expr
      etaReduced = etaReduction betaReduced
  in if etaReduced /= expr 
     then performReduction etaReduced 
     else etaReduced

-- Reducer starts here
expressionReducer :: Lexp -> Lexp
expressionReducer = performReduction

-- Entry point of the program
main = do
  args <- getArgs
  let inputFile = case args of { x:_ -> x; _ -> "input.lambda" }
  let outputFile = case args of { x:y:_ -> y; _ -> "output.lambda" }
  runProgram inputFile outputFile expressionReducer