﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace experimental_newparser.Ast.Expression
{
    public class BinOpExpr : Expression
    {
        public Expression Lhs = null;
        public Expression Rhs = null;
        public string Op = "";
    }
}