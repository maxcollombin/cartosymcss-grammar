parser grammar CartoSymCSSGrammar;
options { tokenVocab=CartoSymCSSLexer; }

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

idOrConstant:
     IDENTIFIER
   | expConstant
   | TRUE
   | FALSE
   | NULL;

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

expConstant: NUMERIC_LITERAL UNIT? | HEX_LITERAL;

expString: CHARACTER_LITERAL;

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

///////////////////////////////
// Expressions: Arrays

expArray:
     LSBR arrayElements? RSBR
   | LPAR arrayElements? RPAR;

arrayElements:
     expression
   | arrayElements COMMA expression ;

///////////////////////////////
// Expressions: Function calls

expCall: IDENTIFIER LPAR arguments RPAR ;

arguments:
   expression
   | arguments COMMA expression;

binaryLogicalOperator: AND | OR ;

unaryLogicalOperator: NOT ;

unaryArithmeticOperator: PLUS | MINUS;

arithmeticOperatorExp:
   POW;

arithmeticOperatorMul:
     MUL
   | DIV
   | IDIV
   | MOD;

arithmeticOperatorAdd:
     MINUS
   | PLUS
;

relationalOperator:
     EQ
   | LT
   | LTEQ
   | GT
   | GTEQ
   | IN
   | NOT IN
   | IS
   | IS NOT
   | LIKE
   | NOT LIKE;

betweenOperator:
     BETWEEN
   | NOT BETWEEN;
