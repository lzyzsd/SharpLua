﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace experimental_newparser.Ast.Expression
{
    public class TableConstructorStringKeyExpr : Expression
    {
        public string Key = "";
        public Expression Value = null;
    }
}
