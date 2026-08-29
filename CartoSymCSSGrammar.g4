parser grammar CartoSymCSSGrammar;
options { tokenVocab=CartoSymCSSLexer; }
import CQL2Expression;

///////////////////////////////
// High level style sheet rules
///////////////////////////////

styleSheet: metadata* variableDef* stylingRuleList?;

variable: AT_SIGN IDENTIFIER;

variableDef: variable EQ expression SEMI;

metadata:
    '.' IDENTIFIER CHARACTER_LITERAL;

// NOTE: Only .name is valid for stylingRuleName
stylingRuleName:
    '.' IDENTIFIER CHARACTER_LITERAL;

stylingRuleList:
     stylingRule
   | stylingRuleList stylingRule;

stylingRule:
   ( selector )*
   LCBR
      stylingRuleName?
      (propertyAssignmentList SEMI)?
      stylingRuleList?
   RCBR;

selector:
     IDENTIFIER
   | LSBR expression RSBR ;

///////////////////////////////
// Expressions
//
// The `expression` combinator lives here (not in CQL2Expression.g4): ANTLR
// cannot let an importing grammar add alternatives to a left-recursive rule
// defined in an imported one, and this rule mixes the pure CQL2 forms
// (idOrConstant, expString, expCall, expArray, the *Operator rules — all
// imported from CQL2Expression) with the CartoSym-specific ones
// (expInstance, variable, tuple).

tuple:
     idOrConstant idOrConstant
   | tuple idOrConstant;

expression:
     idOrConstant                                            # PrimaryExpr

   | expression DOT IDENTIFIER                                # MemberAccessExpr

   | expString                                               # StringExpr
   | expCall                                                 # CallExpr
   | expArray                                                # ArrayExpr

   | expInstance                                             # InstanceExpr

   | LPAR expression RPAR                                     # ParenExpr

   | expression LSBR expConstant RSBR                         # IndexExpr

   // Operations
   | expression arithmeticOperatorExp expression             # PowExpr
   | expression arithmeticOperatorMul expression             # MulExpr
   | expression arithmeticOperatorAdd expression             # AddExpr
   | expression binaryLogicalOperator expression             # LogicalExpr
   | expression relationalOperator expression                # RelationalExpr
   | expression betweenOperator expression AND expression    # BetweenExpr
   | expression QUESTION expression COLON expression         # ConditionalExpr
   | unaryLogicalOperator expression                         # UnaryLogicalExpr
   | unaryArithmeticOperator expression                      # UnaryArithExpr

   | tuple                                                   # TupleExpr

   | variable                                                # VariableExpr
   ;

///////////////////////////////
// Expressions: Instances

expInstance:
   IDENTIFIER?
   LCBR
      propertyAssignmentInferredList?
      SEMI?
   RCBR |
   IDENTIFIER
   LPAR
      propertyAssignmentInferredList?
      SEMI?
   RPAR
   ;

lhValue:
     IDENTIFIER
   | lhValue DOT IDENTIFIER
   | lhValue LSBR expConstant RSBR ;

propertyAssignment:
   lhValue COLON expression;

propertyAssignmentList:
     propertyAssignment
   | propertyAssignmentList SEMI propertyAssignment;

propertyAssignmentInferred:
     propertyAssignment
   | expression
   ;

propertyAssignmentInferredList:
     propertyAssignmentInferred
   | propertyAssignmentInferredList SEMI propertyAssignmentInferred
   | propertyAssignmentInferredList COMMA propertyAssignmentInferred
   ;
