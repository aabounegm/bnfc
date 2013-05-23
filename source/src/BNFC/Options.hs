module BNFC.Options where

import System.Console.GetOpt

-- For the old parser
import Data.Char
import Data.Maybe (listToMaybe)
import Data.List (elemIndex, foldl', sort)
import Control.Monad (when,unless)
import System.FilePath (takeFileName)
import Control.Monad (liftM)
import BNFC.WarningM
import Text.Printf (printf)
import Data.List (intercalate)
import Data.Maybe (catMaybes)
import ErrM
-- Allowed extensions for grammar files
allowed_exts = [ "cf", "bnf", "lbnf", "bnfc" ]

-- Haskell options
data HaskellVariant = StandardHaskell | GADTHaskell | ProfHaskell
  deriving (Show,Eq)
data AlexVersion = Alex1 | Alex2 | Alex3
  deriving (Show,Eq,Ord)
type Makefile = Bool
type UseGLR = Bool
data XMLPrinter = NoXML | XML | XMLT
  deriving (Show,Eq)
type Namespace = String
-- Java options
data JavaVersion = Java4 | Java5
  deriving (Show,Eq)
-- data Mode
--   -- |
--   = Haskell HaskellVariant AlexVersion Bool Namespace Makefile
--   | Java JavaVersion Namespace Makefile
--   | C Makefile
--   -- | C++ options: the first boolean
--   | Cpp Bool Namespace Makefile
--   | Csharp Namespace Makefile
--   | OCaml Makefile

-- * Options getters
-- getGenMakefile :: Mode -> Bool
-- getGenMakefile (Haskell _ _ _ _ b) = b
-- getGenMakefile (Java _ _ b) = b
-- getGenMakefile (C b) = b
-- getGenMakefile (Cpp _ _ b) = b
-- getGenMakefile (Csharp _ b) = b
-- getGenMakefile (OCaml b) = b
-- 
-- getHaskellVariant :: Mode -> HaskellVariant
-- getHaskellVariant (Haskell v _ _ _ _) = v
-- 
-- getAlexVersion :: Mode -> AlexVersion
-- getAlexVersion (Haskell _ v _ _ _) = v
-- 
-- getGLR :: Mode -> Bool
-- getGLR (Haskell _ _ glr _ _) = glr
-- 
-- getNamespace :: Mode -> Namespace
-- getNamespace (Haskell _ _ _ ns _) = ns
-- getNamespace (Java _ ns _) = ns
-- getNamespace (Cpp _ ns _) = ns
-- getNamespace (Csharp ns _) = ns
-- 
-- getJavaVersion :: Mode -> JavaVersion
-- getJavaVersion (Java jv _ _) = jv
-- 
-- 
-- -- * options setters
-- setGenMakefile :: Bool -> Mode -> Mode
-- setGenMakefile mk (Haskell hv av glr ns _) = Haskell hv av glr ns mk
-- setGenMakefile mk (Java jv ns _) = Java jv ns mk
-- setGenMakefile mk (C _) = C mk
-- setGenMakefile mk (Cpp li ns _) = Cpp li ns mk
-- setGenMakefile mk (Csharp ns _) = Csharp ns mk
-- setGenMakefile mk (OCaml _) = OCaml mk
-- 
-- setHaskellVariant :: HaskellVariant -> Mode -> Mode
-- setHaskellVariant hv (Haskell _ av glr ns mk) = Haskell hv av glr ns mk
-- 
-- setAlexVersion :: AlexVersion -> Mode -> Mode
-- setAlexVersion av (Haskell hv _ glr ns mk) = Haskell hv av glr ns mk
-- 
-- setGLR :: Bool -> Mode -> Mode
-- setGLR glr (Haskell hv av _ ns mk) = Haskell hv av glr ns mk
-- 
-- setNamespace :: Namespace -> Mode -> Mode
-- setNamespace ns (Haskell hv av glr _ mk) = Haskell hv av glr ns mk
-- setNamespace ns (Java jv _ mk) = Java jv ns mk
-- setNamespace ns (Cpp li _ mk) = Cpp li ns mk
-- setNamespace ns (Csharp _ mk) = Csharp ns mk
-- 
-- -- * Option parsing
-- 
-- options :: [ OptDescr Mode ]
-- options =
--   -- | Mahor modes
--   [ Option "" ["java4"]   (NoArg $ Java Java4 "" False)
--     "Output Java 1.4 code for use with JLex and CUP (before 2.5 was: -java)"
--   , Option "" ["java5"]   (NoArg $ Java Java5 "" False)
--     "Output Java 1.5 code for use with JLex and CUP"
--   , Option "" ["haskell"] (NoArg $ Haskell StandardHaskell Alex3 False "" False)
--     "Output Haskell code for use with Alex and Happy (default)"
--   , Option "" ["c"]       (NoArg $ C False)
--     "Output C code for use with FLex and Bison"
--   , Option "" ["cpp"]     (NoArg $ Cpp False "" False)
--     "Output C++ code for use with FLex and Bison"
--   , Option "" ["csharp"]  (NoArg $ Csharp "" False)
--     "Output C# code for use with GPLEX and GPPG"
--   , Option "" ["ocaml"]   (NoArg $ OCaml False)
--     "Output OCaml code for use with ocamllex and ocamlyacc" ]
-- 
-- haskellOptions :: [ OptDescr (Mode -> Mode) ]
-- haskellOptions =
--   [ Option "d" [""]             (NoArg undefined)
--     "Put Haskell code in modules Lang.* instead of Lang*"
--   , Option "p" [""]             (ReqArg setNamespace "<name>")
--     "Prepend <name> to the Haskell module names. Dots in the module name create hierarchical modules."
--   , Option "" ["alex1"]         (NoArg $ setAlexVersion Alex1)
--     "Use Alex 1.1 as Haskell lexer tool"
--   , Option "" ["alex2"]         (NoArg $ setAlexVersion Alex2)
--     "Use Alex 2 as haskell lexer tool"
--   , Option "" ["alex3"]         (NoArg $ setAlexVersion Alex3)
--     "Use Alex 3 as Haskell lexer tool (default)"
--   , Option "" ["sharestrings"]  (NoArg undefined)
--     "Use string sharing in Alex 2 lexer"
--   , Option "" ["bytestrings"]   (NoArg undefined)
--     "Use byte string in Alex 2 lexer"
--   , Option "" ["glr"]           (NoArg undefined)
--     "Output Happy GLR parser"
--   , Option "" ["xml"]           (NoArg undefined)
--     "Also generate a DTD and an XML printer"
--   , Option "" ["xmlt"]          (NoArg undefined)
--     "DTD and an XML printer, another encoding" ]
-- 
-- cppOptions :: [ OptDescr (Mode -> Mode) ]
-- cppOptions =
--   [ Option "l" [""]             (NoArg undefined)
--     "Add and set line_number field for all syntax classes"
--   , Option "p" [""]             (NoArg undefined)
--     "Use <namespace> as the C++ namespace" ]
-- 
-- javaOptions :: [ OptDescr (Mode -> Mode) ]
-- javaOptions =
--   [ Option "p" [""]             (NoArg undefined)
--     "Prepend <package> to the Java package name" ]
-- 
-- csharpOptions :: [ OptDescr (Mode -> Mode) ]
-- csharpOptions =
--   [ Option "p" [""]             (NoArg undefined)
--     "Use <namespace> as the C# namespace"
--   , Option "" ["vs"]            (NoArg undefined)
--     "Generate Visual Studio solution/project files"
--   , Option "" ["wcf"]           (NoArg undefined)
--     "Add support for Windows Communication Foundation, by marking abstract syntax classes as DataContracts" ]
-- 
-- 
data Target = TargetC | TargetCPP |TargetCPP_STL
                | TargetCSharp |TargetHaskell |TargetHaskellGADT
                | TargetJava |TargetOCAML |TargetProfile
    deriving (Eq,Show, Bounded, Enum)

-- | Which version of Alex is targeted?

data HappyMode = Standard | GLR
  deriving (Eq,Show)

data SharedOptions = Options
    {
     targets :: [Target],
     make :: Bool,
     alexMode :: AlexVersion,
     inDir :: Bool,
     shareStrings :: Bool,
     byteStrings :: Bool,
     glr :: HappyMode,
     xml :: Int,
     inPackage :: Maybe String, -- ^ The hierarchical package to put
	                        --   the modules in, or Nothing.
     lang :: String, -- ^ Prefix to use in module names
     multi :: Bool,
     cnf :: Bool -- ^ Generate CNF-like tables?
    }
  deriving (Eq,Show)

defaultOptions = Options 
  { make = False, alexMode = Alex3, inDir = False, shareStrings = False
  , byteStrings = False, glr = Standard, xml = 0, inPackage = Nothing
  , lang = "", multi = False, cnf = False, targets = [TargetHaskell] }

anyTarget opts vs = any (isOpt opts) vs
  where isOpt     opts v  = elem v $ targets opts

parseArguments :: Monad m => [String] -> m (SharedOptions,FilePath)
parseArguments args' = do
  let args = (map (filter (not . isSpace)) args')
  let file = last args
  if (head file == '-') then fail "Missing grammar file"
   else do
      let name = takeWhile (/= '.') $ takeFileName file
      let make = elem "-m" args
      let multi = elem "--multilingual" args
      let c = elem "-c" args
      let cpp_no_stl = elem "-cpp_no_stl" args
      let cpp_stl = elem "-cpp_stl" args || elem "-cpp" args
      let csharp = elem "-csharp" args
      let java = elem "-java1.5" args || elem "-java" args
      let ocaml = elem "-ocaml" args
      let fsharp = elem "-fsharp" args
      let haskell = elem "-haskell" args
      let haskellGADT = elem "-gadt" args
      let profile = elem "-prof" args
      let alexMode = foldl' (\m arg ->
                              case arg of
                                "-alex1" -> Alex1
                                "-alex2" -> Alex2
                                "-alex3" -> Alex3
                                _        -> m
                            ) Alex3 args
          alex1 = alexMode == Alex1
          alex2StringSharing = elem "-sharestrings" args
          alex2ByteString    = elem "-bytestrings" args
          glr = "-glr" `elem` args
      let xml = if elem "-xml"  args then 1 else
                if elem "-xmlt" args then 2 else 0
      let inDir = elem "-d" args
      let vsfiles = elem "-vs" args
      let wcfSupport = elem "-wcf" args
      let linenumbers = elem "-l" args -- for C++ STL target
      inPackage <- case elemIndex "-p" args of
		         Nothing -> return Nothing
			 Just i | i < length args - 1 -> return (Just (args!!(i+1)))
			 _ -> do
			      fail "-p option requires an argument"
      let options = Options {make = make,
                             alexMode = alexMode,
                             inDir = inDir,
                             shareStrings = alex2StringSharing,
                             byteStrings = alex2ByteString,
                             glr = if glr then GLR else Standard,
                             xml = xml,
                             inPackage = inPackage,
                             lang = name,
                             multi = multi,
                             cnf = elem "-cnf" args,
                             targets = targets
                             }
          targets0 = [ TargetC |c] ++ [ TargetCPP | cpp_no_stl ] ++ [TargetCPP_STL  |  cpp_stl
                ] ++ [ TargetCSharp | csharp] ++ [TargetHaskellGADT|haskellGADT
                ] ++ [ TargetJava |java] ++ [TargetOCAML |ocaml] ++ [TargetProfile|profile]
          targets = if null targets0 then [TargetHaskell] else targets0
      unless (length targets == 1) $
        fail "Error: only one language mode may be chosen"
      unless (isCfFile file) $
        fail "Error: the input file must end with .cf"
      return (options,file)

isCfFile = isCF . reverse
  where isCF ('f':'c':'.':_)     = True
        isCF ('f':'n':'b':'.':_) = True
        isCF ('f':'n':'b':'l':'.':_) = True
        isCF ('c':'f':'n':'b':'.':_) = True
        isCF _                   = False


-- Backward compatibility: This function makes sure that we stay backward
-- compatible wrt. the old argument names by translating the old arguments
-- to their new equivalent. In addition, it produces wornings messages
-- to be displayed to the user
translateArguments :: [String] -> WithWarnings [String]
translateArguments
  = concatMapM $ translate
      [ ( "-java1.4", ["--java4"])
      , ( "-java1.5", ["--java5"])
      , ( "-java", ["--java"])
      , ( "-c", ["--c"])
      , ( "-cpp", ["--cpp"])
      , ( "-cpp_stl", ["--cpp","--stl"])
      , ( "-cpp_no_stl", ["--cpp","--no-stl"])
      , ( "-csharp", ["--csharp"])
      , ( "-ocaml", ["--ocaml"])
      , ( "-haskell", ["--haskell"])
      , ( "-prof", ["--haskell","--prof"])
      , ( "-gadt", ["--haskell","--gadt"])
      , ( "-alex1", ["--alex1"])
      , ( "-alex2", ["--alex2"])
      , ( "-alex3", ["--alex3"])
      , ( "-sharestrings", ["--sharestrings"])
      , ( "-bytestrings", ["--bytestrings"])
      , ( "-glr", ["--glr"])
      , ( "-bytestrings", ["--bytestrings"])
      , ( "-xml", ["--xml"])
      , ( "-xmlt", ["--xmlt"])
      , ( "-vs", ["--vs"])
      , ( "-wcf", ["--wcf"])
      ]
  where translate :: [(String,[String])] -> String -> WithWarnings [String]
        translate map s
          = case lookup s map of
              Nothing -> return [s]
              Just ss ->
                let msg = printf "Option %s is deprecated, use %s instead"
                                  s (intercalate " " ss)
                in warn msg >> return ss


concatMapM :: Monad m => ( a -> m [b] ) -> [a] -> m [b]
concatMapM f l = mapM f l >>= return . concat

-- | Given a list of arguments, returns a list of error messages
-- one for each deprecated argument in the original list
-- Note that the returned error messages end with a newline
-- to make them consistent with the errors reported by the GetOpt module
lookForDeprecatedOptions :: [String] -> [String]
lookForDeprecatedOptions = catMaybes . map msg
  where deprecated =  [ ("--numeric-version","--version")
                      , ("-multi", "--multilingual") ]
        msg :: String -> Maybe String
        msg arg = do
          newArg <- lookup arg deprecated
          return $ printf "%s is deprecated, use %s instead\n" arg newArg

-- | To decouple the option parsing from the execution of the program,
-- we introduce here a new data structure that holds the result of the
-- parsing of the arguments.
data Mode
  -- An error has been made by the user
  -- e.g. invalid argument/combination of arguments
  = UsageError String
  -- Basic modes: print some info and exits
  | Help | Version
  -- Normal mode, specifying the back end to use,
  -- a list of un-parsed arguments to be passed to the backend
  -- and the path of the input grammar file
  | Target Target [String]
  -- multi-mode: same as above except that more than one backend may be
  -- specified
  -- | Multi [(Target,[String])] FilePath
  deriving (Eq)
instance Show Mode where
  show Help = "--help"
  show Version = "--version"
  show (Target t args) = unwords $ showTarget t:args
  show (UsageError msg) = "Error " ++ show msg

isUsageError :: Mode -> Bool
isUsageError (UsageError _) = True
isUsageError _ = False

showTarget :: Target -> String
showTarget TargetC = "c"
showTarget TargetCPP = "cpp"
showTarget TargetCPP_STL = "cpp-stl"
showTarget TargetCSharp = "c-sharp"
showTarget TargetHaskell = "haskell"
showTarget TargetHaskellGADT = "haskell-gadt"
showTarget TargetJava ="java"
showTarget TargetOCAML ="ocaml"
showTarget TargetProfile ="profile"


-- ~~~ Option parsing
-- This defines bnfc's "global" options, i.e. the options that are allowed
-- before the sub-command
data BnfcOption = OptHelp | OptVersion | OptMultilingual
  deriving (Show, Eq, Ord)
bnfcOptions :: [ OptDescr BnfcOption ]
bnfcOptions = [
  Option [] ["help"]          (NoArg OptHelp)         "show help",
  Option [] ["version"]       (NoArg OptVersion)      "show version number",
  Option [] ["multilingual"]  (NoArg OptMultilingual) "multilingual BNF" ]

parseMode :: [String] -> Mode
parseMode args = fromErrM $ do
  unless (null errors) $ fail (head errors)
  case global of
    Just OptHelp -> return Help
    Just OptVersion -> return Version
    Just OptMultilingual -> undefined
    Nothing | null args' -> return Help
    Nothing -> case target of
      Just t -> return $ Target t args''
      Nothing -> fail $ "Invalid target " ++ head args' -- safe: args' is not null
  where fromErrM (Bad msg)  = UsageError msg
        fromErrM (Ok a)     = a
        -- we use getOpt with RequireOrder which makel getOpt stop option
        -- processing after the first non-option.
        -- The returned tuple consist of:
        -- - the list of processed options
        -- - a list with the remaining arguments
        -- - a list of errors
        (opts,args',errors) =  getOpt RequireOrder bnfcOptions args
        -- The order in which BnfcOption are defined set their
        -- priority
        global = listToMaybe (sort opts)
        -- The code below relies on haskell's lazyness:
        -- we assumes that target will only be needed if args' have
        -- been checked to be non empty
        target = lookup (head args') targetMap
        args'' = tail args'
        targetMap = [ ( "haskell", TargetHaskell )
                    , ( "c", TargetC )
                    , ( "cpp", TargetCPP )
                    , ( "cpp-stl", TargetCPP_STL )
                    , ( "java", TargetJava )
                    , ( "c-sharp", TargetCSharp )
                    , ( "ocaml", TargetOCAML )
                    , ( "haskell-gadt", TargetHaskellGADT )
                    , ( "profile", TargetProfile )
                    ]
