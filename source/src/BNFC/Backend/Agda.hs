{- |  Agda backend.
Generate bindings to Haskell data types for use in Agda.

Example for abstract syntax generated in Haskell backend:
@@
  newtype Id = Id String deriving (Eq, Ord, Show, Read)

  data Def = DFun Type Id [Arg] [Stm]
    deriving (Eq, Ord, Show, Read)

  data Arg = ADecl Type Id
    deriving (Eq, Ord, Show, Read)

  data Stm
      = SExp Exp
      | SInit Type Id Exp
      | SBlock [Stm]
      | SIfElse Exp Stm Stm
    deriving (Eq, Ord, Show, Read)

  data Type = Type_bool | Type_int | Type_double | Type_void
    deriving (Eq, Ord, Show, Read)
@@
This should be accompanied by the following Agda code:
@@
  module <mod> where

  {-# FOREIGN GHC import qualified Data.Text #-}
  {-# FOREIGN GHC import CPP.Abs #-}
  {-# FOREIGN GHC import CPP.Print #-}

  data Id : Set where
    mkId : List Char → Id

  {-# COMPILE GHC Id = data Id (Id) #-}

  data Def : Set where
    dFun : (t : Type) (x : Id) (as : List Arg) (ss : List Stm) → Def

  {-# COMPILE GHC Def = data Def (DFun) #-}

  data Arg : Set where
    aDecl : (t : Type) (x : Id) → Arg

  {-# COMPILE GHC Arg = data Arg (ADecl) #-}

  data Stm : Set where
    sExp    : (e : Exp)                     → Stm
    sInit   : (t : Type) (x : Id) (e : Exp) → Stm
    sBlock  : (ss : List Stm)               → Stm
    sIfElse : (e : Exp) (s s' : Stm)        → Stm

  {-# COMPILE GHC Stm = data Stm
    ( SExp
    | SInit
    | SBlock
    | SIfElse
    ) #-}

  data Type : Set where
    bool int double void : Type

  {-# COMPILE GHC Type = data Type
    ( Type_bool
    | Type_int
    | Type_double
    | Type_void
    ) #-}

  -- Binding the BNFC pretty printer.

  printId  : Id → String
  printId (mkId s) = String.fromList s

  postulate
    printType    : Type    → String
    printExp     : Exp     → String
    printStm     : Stm     → String
    printArg     : Arg     → String
    printDef     : Def     → String
    printProgram : Program → String

  {-# COMPILE GHC printType    = \ t -> Data.Text.pack (printTree (t :: Type)) #-}
  {-# COMPILE GHC printExp     = \ e -> Data.Text.pack (printTree (e :: Exp))  #-}
  {-# COMPILE GHC printStm     = \ s -> Data.Text.pack (printTree (s :: Stm))  #-}
  {-# COMPILE GHC printArg     = \ a -> Data.Text.pack (printTree (a :: Arg))  #-}
  {-# COMPILE GHC printDef     = \ d -> Data.Text.pack (printTree (d :: Def))  #-}
  {-# COMPILE GHC printProgram = \ p -> Data.Text.pack (printTree (p :: Program)) #-}
@@
-}

{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}

module BNFC.Backend.Agda (makeAgda) where

import Prelude'
import qualified Data.List as List
import Text.PrettyPrint

import BNFC.CF
-- import BNFC.Utils
import BNFC.Backend.Base           (Backend, mkfile)
import BNFC.Options                (SharedOptions)
import BNFC.Backend.Haskell.HsOpts (agdaFile, agdaFileM, absFileM, printerFileM)

-- | Entry-point for Agda backend.

makeAgda
  :: String         -- ^ Current time.
  -> SharedOptions  -- ^ Options.
  -> CF             -- ^ Grammar.
  -> Backend
makeAgda time opts cf = do
  mkfile (agdaFile opts) $
    cf2Agda time (agdaFileM opts) (absFileM opts) (printerFileM opts) cf

-- | Generate AST bindings for Agda.

cf2Agda
  :: String  -- ^ Current time.
  -> String  -- ^ Module name.
  -> String  -- ^ Haskell Abs module name.
  -> String  -- ^ Haskell Print module name.
  -> CF      -- ^ Grammar.
  -> String
cf2Agda time mod amod pmod cf = render . vsep $
  [ preamble time
  , hsep [ "module", text mod, "where" ]
  , imports
  , importPragmas amod pmod
  , prIdent
  , absyn dats
  , "-- Binding the BNFC pretty printer"
  , printIdent
  , printer cats
  , empty -- Make sure we terminate the file with a new line.
  ]
  where
  dats = cf2data cf
  cats = map fst dats

-- We prefix the Agda types with "#" to not conflict with user-provided nonterminals.
arrow, charT, intT, listT, stringT, stringFromListT :: Doc
arrow = "→"
charT           = "#Char"
intT            = "Integer"  -- This is the BNFC name for it!
doubleT         = "Double"   -- This is the BNFC name for it!
listT           = "#List"
stringT         = "#String"
stringFromListT = "#stringFromList"

-- | Hack to insert blank lines.

($++$) :: Doc -> Doc -> Doc
d $++$ d' = d $+$ "" $+$ d'

-- | Separate vertically by blank lines.

vsep :: [Doc] -> Doc
vsep = foldr1 ($++$)

-- | Preamble: introductory comments.

preamble :: String -> Doc
preamble time = vcat $
  [ "-- Agda bindings for the Haskell abstract syntax data types."
  , "-- Generated by BNFC at" <+> text time <> "."
  ]

-- -- | Generate Agda module header.
-- --   We parametrized the module over the implementation List, Char, String, and stringFromList.
-- --
-- -- >>> header "AST"
-- -- module AST
-- --   (#List : Set → Set)
-- --   (#Char : Set)
-- --   (#String : Set)
-- --   (#stringFromList : #List #Char → #String)
-- --   where
-- --
-- header :: String -> Doc
-- header mod = vcat . concat $
--   [ [ "module" <+> text mod ]
--   , map (nest 2 . parens) parameters
--   , [ nest 2 $ "where" ]
--   ]
--   where
--   parameters :: [Doc]
--   parameters =
--     [ hsep [ listT, colon, setT, arrow, setT ]
--     , hsep [ charT, colon, setT ]
--     , hsep [ stringT, colon, setT ]
--     , hsep [ stringFromListT, colon, listT, charT, arrow, stringT ]
--     ]

-- | Import statements.

imports :: Doc
imports = vcat . map prettyImport $
  [ ("Agda.Builtin.Char",   [("Char", charT)])
  , ("Agda.Builtin.Float",  [("Float", doubleT)])
  , ("Agda.Builtin.Int",    [("Int", intT)])
  , ("Agda.Builtin.List",   [("List", listT)])
  , ("Agda.Builtin.String", [("String", stringT), ("primStringFromList", stringFromListT) ])
  ]
  where
  prettyImport :: (String, [(String, Doc)]) -> Doc
  prettyImport (m, ren) = prettyList pre lparen rparen semi $
    map (\ (x, d) -> hsep [text x, "to", d ]) ren
    where
    pre = hsep [ "open", "import", text m, "using", "()", "renaming" ]

-- | Import pragmas.
--
-- >>> importPragmas "Foo.Abs" "Foo.Print"
-- {-# FOREIGN GHC import qualified Data.Text #-}
-- {-# FOREIGN GHC import Foo.Abs #-}
-- {-# FOREIGN GHC import Foo.Print #-}
--
importPragmas
  :: String  -- ^ Haskell Abs module
  -> String  -- ^ Haskell Print module
  -> Doc
importPragmas amod pmod = vcat $ map imp [ "qualified Data.Text" , amod, pmod ]
  where
  imp s = hsep [ "{-#", "FOREIGN", "GHC", "import", text s, "#-}" ]

-- * Bindings for the AST.

-- | Pretty-print identifier type.

prIdent :: Doc
prIdent =
  prettyData "Id" [("mkId", [ListCat (Cat "#Char")])]
  $++$
  pragmaData "Id" [("Id", [])]

-- | Pretty-print abstract syntax definition in Agda syntax.
--
--   We print this as one big mutual block rather than doing a
--   strongly-connected component analysis and topological
--   sort by dependency order.
--
absyn :: [Data] -> Doc
absyn = vsep . ("mutual" :) . concatMap (map (nest 2) . prData)

-- | Pretty-print Agda data types and pragmas for AST.
--
-- >>> vsep $ prData (Cat "Nat", [ ("zero", []), ("suc", [Cat "Nat"]) ])
-- data Nat : Set where
--   zero : Nat
--   suc : Nat → Nat
-- <BLANKLINE>
-- {-# COMPILE GHC Nat = data Nat
--   ( zero
--   | suc
--   ) #-}
--
-- We return a list of 'Doc' rather than a single 'Doc' since want
-- to intersperse empty lines and indent it later.
-- If we intersperse the empty line(s) here to get a single 'Doc',
-- we will produce whitespace lines after applying 'nest'.
-- This is a bit of a design problem of the pretty print library:
-- there is no native concept of a blank line; @text ""@ is a bad hack.
--
prData :: Data -> [Doc]
prData (Cat d, cs) = [ prettyData d cs , pragmaData d cs ]
prData (c    , _ ) = error $ "prData: unexpected category " ++ show c

-- | Pretty-print AST definition in Agda syntax.
--
-- >>> prettyData "Nat" [ ("zero", []), ("suc", [Cat "Nat"]) ]
-- data Nat : Set where
--   zero : Nat
--   suc : Nat → Nat
-- >>> let stm = Cat "Stm" in prettyData "Stm" [ ("block", [ListCat stm]), ("while", [Cat "Exp", stm]) ]
-- data Stm : Set where
--   block : #List Stm → Stm
--   while : Exp → Stm → Stm
--
prettyData :: String -> [(Fun, [Cat])] -> Doc
prettyData d cs = vcat $
  [ hsep [ "data", text d, colon, "Set", "where" ] ] ++
  map (nest 2 . prettyConstructor d) cs

-- | Generate pragmas to bind Haskell AST to Agda.
--
-- >>> pragmaData "Empty" []
-- {-# COMPILE GHC Empty = data Empty () #-}
--
-- >>> pragmaData "Nat" [ ("zero", []), ("suc", [Cat "Nat"]) ]
-- {-# COMPILE GHC Nat = data Nat
--   ( zero
--   | suc
--   ) #-}
pragmaData :: String -> [(Fun, [Cat])] -> Doc
pragmaData d cs = prettyList pre lparen (rparen <+> "#-}") "|" $
  map (prettyFun . fst) cs
  where
  pre = hsep [ "{-#", "COMPILE", "GHC", text d, equals, "data", text d ]

-- | Pretty-print since rule as Agda constructor declaration.
--
-- >>> prettyConstructor "D" ("c", [Cat "A", Cat "B", Cat "C"])
-- c : A → B → C → D
-- >>> prettyConstructor "D" ("c", [])
-- c : D
prettyConstructor :: String -> (Fun,[Cat]) -> Doc
prettyConstructor d (c, as) = hsep . concat $
  [ [ prettyFun c, colon ]
  , List.intersperse arrow $ map prettyCat $ as ++ [Cat d]
  ]

-- * Generate bindings for the pretty printer

-- | Generate Agda code to print identifiers.
--
-- >>> printIdent
-- printId : Id → #String
-- printId (mkId s) = #stringFromList s
--
printIdent :: Doc
printIdent = vcat
  [ hsep [ "printId", colon, "Id", arrow, stringT ]
  , hsep [ "printId", lparen <> "mkId" <+> "s" <> rparen, equals, stringFromListT, "s" ]
  ]

-- | Generate Agda bindings to printers for AST.
--
-- >>> printer $ map Cat [ "Exp", "Stm" ]
-- postulate
--   printExp : Exp → #String
--   printStm : Stm → #String
-- <BLANKLINE>
-- {-# COMPILE GHC printExp = \ x -> Data.Text.pack (printTree (x :: Exp)) #-}
-- {-# COMPILE GHC printStm = \ x -> Data.Text.pack (printTree (x :: Stm)) #-}
--
printer :: [Cat] -> Doc
printer cats =
  vcat ("postulate" : map (nest 2 . prettyTySig) ts)
  $++$
  vcat (map pragmaBind ts)
  where
  catName :: Cat -> String
  catName (Cat x) = x
  ts = map catName cats
  prettyTySig x = hsep [ text ("print" ++ x), colon, text x, arrow, stringT ]
  pragmaBind  x = hsep
    [ "{-#", "COMPILE", "GHC", text ("print" ++ x), equals, "\\", "x", "->"
    , "Data.Text.pack", parens ("printTree" <+> parens ("x" <+> "::" <+> text x)), "#-}"
    ]

-- * Auxiliary functions

-- | Pretty-print a rule name.
prettyFun :: Fun -> Doc
prettyFun = text

-- | Pretty-print a category as Agda type.
prettyCat :: Cat -> Doc
prettyCat = \case
  Cat s        -> text s
  TokenCat s   -> text s
  CoercCat s _ -> text s
  ListCat c    -> listT <+> parensIf (compositeCat c) (prettyCat c)
  InternalCat  -> error "prettyCat: unexpected case InternalCat"

-- | Is the Agda type corresponding to 'Cat' composite (or atomic)?
compositeCat :: Cat -> Bool
compositeCat = \case
  ListCat{} -> True
  _         -> False

parensIf :: Bool -> Doc -> Doc
parensIf = \case
  True  -> parens
  False -> id

-- | Print a list of 0-1 elements on the same line as some preamble
--   and from 2 elements on the following lines, indented.
--
-- >>> prettyList ("foo" <+> equals) lbrack rbrack comma []
-- foo = []
-- >>> prettyList ("foo" <+> equals) lbrack rbrack comma [ "a" ]
-- foo = [a]
-- >>> prettyList ("foo" <+> equals) lbrack rbrack comma [ "a", "b" ]
-- foo =
--   [ a
--   , b
--   ]
prettyList
  :: Doc   -- ^ Preamble.
  -> Doc   -- ^ Left parenthesis.
  -> Doc   -- ^ Right parenthesis.
  -> Doc   -- ^ Separator (usually not including spaces).
  -> [Doc] -- ^ List item.
  -> Doc
prettyList pre lpar rpar sepa = \case
  []     -> pre <+> lpar <> rpar
  [d]    -> pre <+> lpar <> d <> rpar
  (d:ds) -> vcat . (pre :) . map (nest 2) . concat $
    [ [ lpar <+> d ]
    , map (sepa <+>) ds
    , [ rpar ]
    ]
