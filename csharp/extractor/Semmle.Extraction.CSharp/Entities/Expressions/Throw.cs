using Microsoft.CodeAnalysis.CSharp.Syntax;
using Semmle.Extraction.Kinds;
using System.IO;

namespace Semmle.Extraction.CSharp.Entities.Expressions
{
    class Throw : Expression<ThrowExpressionSyntax>
    {
        Throw(ExpressionNodeInfo info) : base(info.SetKind(ExprKind.THROW)) { }

        public static Expression Create(ExpressionNodeInfo info) => new Throw(info).TryPopulate();

        protected override void PopulateExpression(TextWriter trapFile)
        {
            Create(cx, Syntax.Expression, this, 0);
        }
    }
}
