{-# language CPP #-}
{-# language QuasiQuotes #-}
{-# language TemplateHaskell #-}

#ifndef ENABLE_INTERNAL_DOCUMENTATION
{-# OPTIONS_HADDOCK hide #-}
#endif

module OpenCV.Internal.C.FinalizerTH
    ( FinalizerType(..)
    , mkFinalizer
    ) where

import "base" Foreign.Ptr ( Ptr, FunPtr )
import "base" Data.Monoid ( (<>) )
import "base" Data.List ( intercalate )
import qualified "inline-c-cpp" Language.C.Inline.Cpp as C
import "template-haskell" Language.Haskell.TH

data FinalizerType
   = DeletePtr
   | ReleaseDeletePtr

{- | Generates a function that deletes a C++ object via @delete@.

Example:

> mkFinalizer DeletePtr "deleteFoo" "CFoo" ''Foo

Generated code (stylized):

> 'C.verbatim' "extern \"C\""
> {
>   void deleteFoo(CFoo * obj)
>   {
>     delete obj;
>   }
> }

> foreign import ccall "&deleteFoo" deleteFoo :: FunPtr (Ptr Foo -> IO ())

And

> mkFinalizer ReleaseDeletePtr "deleteFoo" "CFoo" ''Foo

generates an additional

> obj->release();

before the @delete@.
-}
mkFinalizer :: FinalizerType -> String -> String -> Name -> DecsQ
mkFinalizer finalizerType name cType haskellCType = do
    finalizerImportDec <- finalizerImport
    cFinalizerDecs <- C.verbatim cFinalizerSource
    pure $ finalizerImportDec : cFinalizerDecs
  where
    finalizerImport :: DecQ
    finalizerImport =
        forImpD CCall Safe ("&" <> name) (mkName name)
          [t| FunPtr (Ptr $(conT haskellCType) -> IO ()) |]

    cFinalizerSource :: String
    cFinalizerSource =
        intercalate "\n" $
          [ "extern \"C\""
          , "{"
          , "  void " <> name <> "(" <> cType <> " * obj)"
          , "  {"
          ]
          <>
          case finalizerType of
            DeletePtr -> []
            ReleaseDeletePtr -> ["    obj->release();"]
          <>
          [ "    delete obj;"
          , "  }"
          , "}"
          ]
