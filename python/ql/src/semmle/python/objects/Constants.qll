import python

private import semmle.python.objects.TObject
private import semmle.python.objects.ObjectInternal
private import semmle.python.pointsto.PointsTo
private import semmle.python.pointsto.MRO
private import semmle.python.pointsto.PointsToContext
private import semmle.python.types.Builtins


/** Class representing constants.
 * Includes `None`, `True` and `False` as
 * well as strings and integers.
 */
abstract class ConstantObjectInternal extends ObjectInternal {

    override ClassDecl getClassDeclaration() {
        none()
    }

    override boolean isClass() { result = false }

    override predicate notTestableForEquality() { none() }

    override predicate callResult(PointsToContext callee, ObjectInternal obj, CfgOrigin origin) {
        // Constants aren't callable
        none()
    }

    override predicate callResult(ObjectInternal obj, CfgOrigin origin) {
        // Constants aren't callable
        none()
    }

    override ControlFlowNode getOrigin() {
        none()
    }

    override predicate calleeAndOffset(Function scope, int paramOffset) {
        none()
    }

    pragma [noinline] override predicate attribute(string name, ObjectInternal value, CfgOrigin origin) {
        PointsToInternal::attributeRequired(this, name) and
        exists(ObjectInternal cls_attr, CfgOrigin attr_orig |
            this.getClass().(ClassObjectInternal).lookup(name, cls_attr, attr_orig) and
            cls_attr.isDescriptor() = true and cls_attr.descriptorGetInstance(this, value, origin)
        )
    }

    pragma [noinline] override predicate attributesUnknown() { none() }

    override predicate subscriptUnknown() { none() }

    override boolean isDescriptor() { result = false }

    pragma [noinline] override predicate descriptorGetClass(ObjectInternal cls, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate descriptorGetInstance(ObjectInternal instance, ObjectInternal value, CfgOrigin origin) { none() }

    pragma [noinline] override predicate binds(ObjectInternal instance, string name, ObjectInternal descriptor) {
        exists(ClassObjectInternal cls |
            receiver_type(_, name, this, cls) and
            cls.lookup(name, descriptor, _) and
            descriptor.isDescriptor() = true
        ) and
        this = instance
    }

    override string getName() { none() }

}

private abstract class BooleanObjectInternal extends ConstantObjectInternal {

    BooleanObjectInternal() {
        this = TTrue() or this = TFalse()
    }


    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("bool"))
    }

    override int length() { none() }

    override string strValue() {
        none()
    }

}

private class TrueObjectInternal extends BooleanObjectInternal, TTrue {

    override string toString() {
        result = "bool True"
    }

    override boolean booleanValue() {
        result = true
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        node.(NameNode).getId() = "True" and context.appliesTo(node)
    }

    override int intValue() {
        result = 1
    }

    override Builtin getBuiltin() {
        result = Builtin::special("True")
    }

}

private class FalseObjectInternal extends BooleanObjectInternal, TFalse {

    override string toString() {
        result = "bool False"
    }

    override boolean booleanValue() {
        result = false
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        node.(NameNode).getId() = "False" and context.appliesTo(node)
    }

    override int intValue() {
        result = 0
    }

    override Builtin getBuiltin() {
        result = Builtin::special("False")
    }

}

private class NoneObjectInternal extends ConstantObjectInternal, TNone {

    override string toString() {
        result = "None"
    }

    override boolean booleanValue() {
        result = false
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("NoneType"))
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        node.(NameNode).getId() = "None" and context.appliesTo(node)
    }

    override Builtin getBuiltin() {
        result = Builtin::special("None")
    }

    override int intValue() {
        none()
    }

    override string strValue() {
        none()
    }

    override int length() { none() }

}


private class IntObjectInternal extends ConstantObjectInternal, TInt {

    override string toString() {
        result = "int " + this.intValue().toString()
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        context.appliesTo(node) and
        node.getNode().(IntegerLiteral).getValue() = this.intValue()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("int"))
    }

    override Builtin getBuiltin() {
        result.intValue() = this.intValue()
    }

    override int intValue() {
        this = TInt(result)
    }

    override string strValue() {
        none()
    }

    override boolean booleanValue() {
        this.intValue() = 0 and result = false
        or
        this.intValue() != 0 and result = true
    }

    override int length() { none() }

}

private class FloatObjectInternal extends ConstantObjectInternal, TFloat {

    override string toString() {
        if this.floatValue() = this.floatValue().floor() then (
            result = "float " + this.floatValue().floor().toString() + ".0"
        ) else (
            result = "float " + this.floatValue().toString()
        )
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        context.appliesTo(node) and
        node.getNode().(FloatLiteral).getValue() = this.floatValue()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("float"))
    }

    override Builtin getBuiltin() {
        result.floatValue() = this.floatValue()
    }

    private float floatValue() {
        this = TFloat(result)
    }

    override int intValue() {
        this = TFloat(result)
    }

    override string strValue() {
        none()
    }

    override boolean booleanValue() {
        this.floatValue() = 0.0 and result = false
        or
        this.floatValue() != 0.0 and result = true
    }

    override int length() { none() }

}


private class UnicodeObjectInternal extends ConstantObjectInternal, TUnicode {

    override string toString() {
        result =  "'" + this.strValue() + "'"
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        context.appliesTo(node) and
        node.getNode().(StrConst).getText() = this.strValue() and
        node.getNode().(StrConst).isUnicode()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("unicode"))
    }

    override Builtin getBuiltin() {
        result.(Builtin).strValue() = this.strValue() and
        result.getClass() = Builtin::special("unicode")
    }

    override int intValue() {
        none()
    }

    override string strValue() {
        this = TUnicode(result)
    }

    override boolean booleanValue() {
        this.strValue() = "" and result = false
        or
        this.strValue() != "" and result = true
    }

    override int length() {
        result = this.strValue().length()
    }

}

private class BytesObjectInternal extends ConstantObjectInternal, TBytes {

    override string toString() {
        result =  "'" + this.strValue() + "'"
    }

    override predicate introducedAt(ControlFlowNode node, PointsToContext context) {
        context.appliesTo(node) and
        node.getNode().(StrConst).getText() = this.strValue() and
        not node.getNode().(StrConst).isUnicode()
    }

    override ObjectInternal getClass() {
        result = TBuiltinClassObject(Builtin::special("bytes"))
    }

    override Builtin getBuiltin() {
        result.(Builtin).strValue() = this.strValue() and
        result.getClass() = Builtin::special("bytes")
    }

    override int intValue() {
        none()
    }

    override string strValue() {
        this = TBytes(result)
    }

    override boolean booleanValue() {
        this.strValue() = "" and result = false
        or
        this.strValue() != "" and result = true
    }

    override int length() {
        result = this.strValue().length()
    }

}



