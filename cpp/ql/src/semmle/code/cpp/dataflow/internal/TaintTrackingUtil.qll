/**
 * Provides classes for performing local (intra-procedural) and
 * global (inter-procedural) taint-tracking analyses.
 *
 * We define _taint propagation_ informally to mean that a substantial part of
 * the information from the source is preserved at the sink. For example, taint
 * propagates from `x` to `x + 100`, but it does not propagate from `x` to `x >
 * 100` since we consider a single bit of information to be too little.
 */

private import semmle.code.cpp.models.interfaces.DataFlow
private import semmle.code.cpp.models.interfaces.Taint

private module DataFlow {
  import semmle.code.cpp.dataflow.internal.DataFlowUtil
}

/**
 * Holds if taint propagates from `nodeFrom` to `nodeTo` in exactly one local
 * (intra-procedural) step.
 */
predicate localTaintStep(DataFlow::Node src, DataFlow::Node sink) {
  DataFlow::localFlowStep(src, sink) or
  localAdditionalTaintStep(src, sink)
}

/**
 * Holds if the additional step from `src` to `sink` should be included in all
 * global taint flow configurations.
 */
predicate defaultAdditionalTaintStep(DataFlow::Node src, DataFlow::Node sink) {
  localAdditionalTaintStep(src, sink)
}

/**
 * Holds if `node` should be a barrier in all global taint flow configurations
 * but not in local taint.
 */
predicate defaultTaintBarrier(DataFlow::Node node) { none() }

/**
 * Holds if taint can flow in one local step from `nodeFrom` to `nodeTo` excluding
 * local data flow steps. That is, `nodeFrom` and `nodeTo` are likely to represent
 * different objects.
 */
predicate localAdditionalTaintStep(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) {
  // Taint can flow through expressions that alter the value but preserve
  // more than one bit of it _or_ expressions that follow data through
  // pointer indirections.
  exists(Expr exprFrom, Expr exprTo |
    exprFrom = nodeFrom.asExpr() and
    exprTo = nodeTo.asExpr()
  |
    exprFrom = exprTo.getAChild() and
    not noParentExprFlow(exprFrom, exprTo) and
    not noFlowFromChildExpr(exprTo)
    or
    // Taint can flow from the `x` variable in `x++` to all subsequent
    // accesses to the unmodified `x` variable.
    //
    // `DataFlow` without taint specifies flow from `++x` and `x += 1` into the
    // variable `x` and thus into subsequent accesses because those expressions
    // compute the same value as `x`. This is not the case for `x++`, which
    // computes a different value, so we have to add that ourselves for taint
    // tracking. The flow from expression `x` into `x++` etc. is handled in the
    // case above.
    exprTo = DataFlow::getAnAccessToAssignedVariable(exprFrom.(PostfixCrementOperation))
  )
  or
  // Taint can flow through modeled functions
  exprToDefinitionByReferenceStep(nodeFrom.asExpr(), nodeTo.asDefiningArgument())
}

/**
 * Holds if taint may propagate from `source` to `sink` in zero or more local
 * (intra-procedural) steps.
 */
predicate localTaint(DataFlow::Node source, DataFlow::Node sink) { localTaintStep*(source, sink) }

/**
 * Holds if taint can flow from `e1` to `e2` in zero or more
 * local (intra-procedural) steps.
 */
predicate localExprTaint(Expr e1, Expr e2) {
  localTaint(DataFlow::exprNode(e1), DataFlow::exprNode(e2))
}

/**
 * Holds if we do not propagate taint from `fromExpr` to `toExpr`
 * even though `toExpr` is the AST parent of `fromExpr`.
 */
private predicate noParentExprFlow(Expr fromExpr, Expr toExpr) {
  fromExpr = toExpr.(ConditionalExpr).getCondition()
  or
  fromExpr = toExpr.(CommaExpr).getLeftOperand()
  or
  fromExpr = toExpr.(AssignExpr).getLValue() // LHS of `=`
}

/**
 * Holds if we do not propagate taint from a child of `e` to `e` itself.
 */
private predicate noFlowFromChildExpr(Expr e) {
  e instanceof ComparisonOperation
  or
  e instanceof LogicalAndExpr
  or
  e instanceof LogicalOrExpr
  or
  e instanceof Call
  or
  e instanceof SizeofOperator
  or
  e instanceof AlignofOperator
  or
  e instanceof ClassAggregateLiteral
  or
  e instanceof FieldAccess
}

private predicate exprToDefinitionByReferenceStep(Expr exprIn, Expr argOut) {
  exists(DataFlowFunction f, Call call, FunctionOutput outModel, int argOutIndex |
    call.getTarget() = f and
    argOut = call.getArgument(argOutIndex) and
    outModel.isOutParameterPointer(argOutIndex) and
    exists(int argInIndex, FunctionInput inModel | f.hasDataFlow(inModel, outModel) |
      // Taint flows from a pointer to a dereference, which DataFlow does not handle
      // memcpy(&dest_var, tainted_ptr, len)
      inModel.isInParameterPointer(argInIndex) and
      exprIn = call.getArgument(argInIndex)
    )
  )
  or
  exists(TaintFunction f, Call call, FunctionOutput outModel, int argOutIndex |
    call.getTarget() = f and
    argOut = call.getArgument(argOutIndex) and
    outModel.isOutParameterPointer(argOutIndex) and
    exists(int argInIndex, FunctionInput inModel | f.hasTaintFlow(inModel, outModel) |
      inModel.isInParameterPointer(argInIndex) and
      exprIn = call.getArgument(argInIndex)
      or
      inModel.isInParameterPointer(argInIndex) and
      call.passesByReference(argInIndex, exprIn)
      or
      inModel.isInParameter(argInIndex) and
      exprIn = call.getArgument(argInIndex)
    )
  )
}
