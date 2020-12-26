if(FALSE) {
 library(Rllvm)
 m = parseIR("fibOnly.ll")
 source("genXPathWrapper.R")
 m2 = clone(m)
 xp = genXPathWrapper(m2$fib)
 
 library(XML)
 llvmAddSymbol("xmlXPathPopNumber", "xmlXPathNewFloat", "valuePush")

 ee = ExecutionEngine(m2)
 xp  = getPointerToFunction(m2$xpathfib, ee)@ref

 doc = xmlParse("doc.xml")
 ll = getNodeSet(doc, "//value[ fib(number(.)) > 10 ]", xpathFuns = list(fib = xp))
}

genXPathWrapper =
    #
    # For a given LLVM routine (fun), create an XPath wrapper.
    # The wrapper pops the arguments off the XPath stack, converting them to native types
    # and then calls fun.  It then converts the result back to an XPath object and pushes it onto the stack.
    # We check the number of arguments in the XPath call is the same as the number of parameters expected by
    # fun. If not, we call xmlXPathErr().
    #
function(fun, params = getParameters(fun), retType = getReturnType(fun), module = as(fun, "Module"),
          funName = sprintf("xpath%s", getName(fun)))
{
       # declare new wrapper routine with 2 parameters xmlXPathContent pointer and int of number of arguments.
     f = Function(funName, VoidType, list(ctxt = pointerType(VoidType), nargs = Int32Type), module = module)
     
     nparams = getParameters(f)
     ctxt = nparams[[1]]
     nargs = nparams[[2]]
     b = Block(f)
     ir = IRBuilder(b)

      # We have the initial block that determines if the number of arguments is correct. If not, jump to
      # errBlock which calls xmlXPathErr
      # Otherwise, jump to the bodyBlock which performs the computations.
      # And both errBlock and bodyBlock jump to returnBlock to exit the routine.
     bodyBlock = Block(f)
     errBlock = Block(f)
     returnBlock = Block(f)

       # Initial block - compare nargs to expected number of parameters from wrapped routine
     cmp = createICmp(ir, ICMP_EQ, nparams[[2]], ir$createIntegerConstant(length(params), getContext(module)))     
     createCondBr(ir, cmp, bodyBlock, errBlock)

       # create the bodyBlock code
     ir$setInsertPoint(bodyBlock)
     args = lapply(params, function(p)
                              popArg(ir, getType(p), ctxt, module))

      # call the function being wrapped, i.e. the original function of interest.
     val = createCall(ir, fun, .args = args)

     pushResult(ir, val, retType, ctxt, module)
     ir$createBr(returnBlock)

       # Create the errBlock code.
     ir$setInsertPoint(errBlock)
     createXPathError(ir, nparams, length(params), module, returnBlock, getName(fun))

       # Create the simple returnBlock code which is just return with a void.
     ir$setInsertPoint(returnBlock)
     createReturn(ir)
     
     f
}


createXPathError =
    #
    #  Setup error handling code in current block (assumes caller has managed the blocks and
    #  the IRBuilder so we are in this error block) to call xmlXPathErr(ctxt, errorNum = 12)
    #  This only handles incorrect number of arguments in call to our wrapped routine.
    #
    #  Currently ignores varargs.
    #
function(ir, params, numExpected, module, returnBlock, origFunName)
{
    xmlXPathErr = Function("xmlXPathErr", VoidType, list(pointerType(VoidType), Int32Type), module)
    ir$createCall(xmlXPathErr, params[[1]], ir$createIntegerConstant(12L, getContext(module)))
    ir$createBr(returnBlock)
}

popArg =
    #
    # Code to pop an argument from the XPath call as a native compiled type.
    # Determine the type expected for this parameter in the wrapped routine and
    # pop an instance of that most appropriate type from the XPath stack.
    # Cast the resulting value to the more specific native type expected by the routine.
    #
function(ir, ty, ctxt, module)
{

    # Add the definition for xmlXPathPop....
    #XXX generalize
    if(identical(ty, Int1Type))
       pop = Function("xmlXPathPopBoolean", Int32Type, list(pointerType(VoidType)), module = module)        
    else if(isIntegerType(ty) || identical(ty, DoubleType)) 
       pop = Function("xmlXPathPopNumber", DoubleType, list(pointerType(VoidType)), module = module)
    else if(identical(StringType, ty))
       pop = Function("xmlXPathPopString", pointerType(Int32Type), list(pointerType(VoidType)), module = module)
    else  #XXX not correct default.
        pop = Function("xmlXPathPopNodeSet", pointerType(Int32Type), list(pointerType(VoidType)), module = module)                
   k = createCall(ir, pop, ctxt)

   if(!identical(getType(k) , ty)) {
       #XX generalize
     createCast(ir, Rllvm:::FPToSI, k, ty)
   } else
     k
}

pushResult =
    #
    # Arrange the call to valuePush(), converting the return value from our wrappee function
    # to an XPath object.  Currently can handle Boolean, Float and CString, or variants that can be
    # cast to one of these, e.g., int to Float.
    #
function(ir, val, retType, ctxt, module)
{

      # Determine which xmlXPathNew routine to call to convert the return value from our wrapped routine
      # to an appropriate XPath object.
    if(identical(retType, Int1Type))
       xnew = Function("xmlXPathNewBoolean", pointerType(VoidType), list(Int32Type), module = module)        
    else if(isIntegerType(retType) || identical(DoubleType, retType))
       xnew = Function("xmlXPathNewFloat", pointerType(VoidType), list(DoubleType), module = module)
    else if(identical(StringType, retType) || (isPointerType(retType) && identical(Int8Type, getElementType(retType))))
        xnew = Function("xmlXPathNewCString", pointerType(VoidType), list(StringType), module = module)
    else
        stop("no matching type")

    ty = getType(getParameters(xnew)[[1]])
    if(!identical(ty, retType)) {
        #XXX  make more general
        val = createCast(ir, Rllvm:::SIToFP, val, ty)
    }

     # Create the new XPath object
    xval = createCall(ir, xnew, val)

    valuePush = Function("valuePush", Int32Type, list(pointerType(VoidType), pointerType(VoidType)), module = module)
     # Call valuePush() with the xmlXPath context and the newly created XPath object
    createCall(ir, valuePush, ctxt, xval)
}
