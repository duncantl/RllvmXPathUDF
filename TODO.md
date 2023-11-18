+ find where our libraries are looking for header files.

+ genXPathWrapper.R - coercing int1 to floating point!

+  in genXPathWrapper.R, if declare xmlXPathPopString with return type StringType (rather than
   pointerType(Int8Type)) get an error about not compiling "  This does not compile as-is for LLVM4.0 or higher"

+ m[["regex", value = TRUE]] gives nonsense

+ createGlobal - 
   + √ get the local_unnamed_addr to appear, not external
   + √ initialization to null.
