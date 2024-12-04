:- [facts].
:- [helper].

%replace "fail" for your solution. It is simply a placeholder to avoid binding for the starter code.
nlp_parse(['Get' | QueryRemainder], [command, TableMetadata, QueryOperation]) :-
    table_and_column_info(QueryRemainder, TableMetadata, RemainingWords),
    determine_query_operation(RemainingWords, QueryOperation).

% Parse command operations
determine_query_operation([], []).
determine_query_operation(Tokens, Operation) :-
    ( Tokens = ['.' | _],
        Operation = []
    ; Tokens = [Key, TableName, 'by', 'their', JoinColumn, '.' | _],
        member(Key, ['linking', 'connecting']),
        Operation = [join, TableName, JoinColumn]
    ; Tokens = ['such', 'that', 'its', 'values', 'are', 'either' | T],
        Operation = [matches, ValueList],
        build_value_list(T, ValueList, _)
    ; Tokens = ['such', 'that', Column, 'matches', 'values', 'within', 'the', TargetColumn, 'in', TableName | T],
        Operation = [matches, Column, [command, [[TargetColumn, TableName]], SubOperation]],
        ( T = ['where' | ConditionRest] ->
            execute_condition(ConditionRest, WhereClause),
            SubOperation = [where, WhereClause]
        ; SubOperation = []
        )
    ; Tokens = ['such', 'that' | T],
        Operation = [where, Conditions],
        execute_condition(T, Conditions)
    ; Tokens = ['where' | T],
        Operation = [where, Conditions],
        execute_condition(T, Conditions)
    ).

% Parse basic command structure
execute_query([command, TableMetadata, QueryOperation], ResultSet) :-
    process_tables(TableMetadata, QueryOperation, ResultSet).

% Parse individual commands and evaluate
parse_and_evaluate(_, [], []) :- !.
parse_and_evaluate(part1, [[_, WordList] | RemainingCommands], _) :-
    nlp_parse(WordList, ParsedQuery),
    write(ParsedQuery),nl,
    parse_and_evaluate(part1, RemainingCommands, _).
parse_and_evaluate(part2, [[Line, WordList] | RemainingCommands], _) :-
    write(Line), nl,
    nlp_parse(WordList, ParsedQuery),
    execute_query(ParsedQuery, QueryResults),
    %write("\t"),write(QueryResults),nl,
    print_tables(QueryResults),
    parse_and_evaluate(part2, RemainingCommands, _).
    

% Gathers table and columns 
table_and_column_info(InputWords, TableSpecs, RemainingWords) :-
    table_column_detail(InputWords, TableSpec, RestOfWords),
    (RestOfWords = ['and' | AdditionalWords] ->
        table_and_column_info(AdditionalWords, MoreTableSpecs, RemainingWords),
        TableSpecs = [TableSpec | MoreTableSpecs]
    ;
        TableSpecs = [TableSpec],
        RemainingWords = RestOfWords
    ).

% Gathers table column detail
table_column_detail(['all', 'from', TableName | T], [all, TableName], T).
table_column_detail(Input, [ColumnList, TableName], T) :-
    column_sequencing(Input, ColumnList, ['from', TableName | T]).

% Locates the column sequence
column_sequencing([Column, ',' | T], [Column | MoreColumns], RemainingWords) :-
    column_sequencing(T, MoreColumns, RemainingWords).
column_sequencing([Column, 'and' | T], [Column | MoreColumns], RemainingWords) :-
    column_sequencing(T, MoreColumns, RemainingWords).
column_sequencing([Column, 'from' | T], [Column], T).
column_sequencing([Column | T], [Column], T).

% Creates a list of values
build_value_list([X, ',', 'or', X_end, '.' | _], [X, X_end], _).
build_value_list([X, ',', 'or', X_end | _], [X, X_end], _).
build_value_list([X, 'or', X_end, '.' | _], [X, X_end], _).
build_value_list([X, 'or', X_end | _], [X, X_end], _).
build_value_list([X, ',' | T], [X | AdditionVals], Remaining) :-
    build_value_list(T, AdditionVals, Remaining).
build_value_list([X, ',', '.' | _], [X], _).
build_value_list([X, '.' | _], [X], _).
build_value_list([X], [X], _).

% Determine current condition and execute
execute_condition(X, EndCondition) :-
    ( append(ConditionPart, ['and' | T], X) ->
        execute_condition(ConditionPart, FirstCondition),
        execute_condition(T, SecondCondition),
        EndCondition = [and, FirstCondition, SecondCondition]
    ; append(ConditionPart, ['or' | T], X) ->
        execute_condition(ConditionPart, FirstCondition),
        execute_condition(T, SecondCondition),
        EndCondition = [or, FirstCondition, SecondCondition]
    ; X = ['either' | T] ->
        execute_condition(T, EndCondition)
    ; X = [Column | T] ->
        perform_operation(T, Operator, Value, _),
        EndCondition = [condition, Column, Operator, Value]
    ).

% Determines the operationa and performs it
perform_operation(InputVal, Operator, Item, T) :-
    ( InputVal = ['is', 'less', 'than', Item | T] -> Operator = '<'
    ; InputVal = ['less', 'than', Item | T] -> Operator = '<'
    ; InputVal = ['is', 'greater', 'than', Item | T] -> Operator = '>'
    ; InputVal = ['greater', 'than', Item | T] -> Operator = '>'
    ; InputVal = ['equals', Item | T] -> Operator = '='
    ; InputVal = ['is', Item | T] -> Operator = '='
    ; InputVal = [OperationString, Item | T],
        ( OperationString = 'equals' -> Operator = '='
        ; OperationString = 'is' -> Operator = '='
        ; OperationString = 'less' -> Operator = '<'
        ; OperationString = 'greater' -> Operator = '>'
        )
    ).

% Use information within the tables to recreate them
process_tables([], _, []).
process_tables([[Columns, TableName] | RemainingTables], QueryOperation, [[TableName, SelectedColumns, FilteredData] | MoreResults]) :-
    table(TableName, HeaderList),
    (Columns == all ->
        SelectedColumns = HeaderList
    ;
        SelectedColumns = Columns
    ),
    table(TableName, HeaderList),
    findall(ResultRow,
        (row(TableName, CompleteRow),
            evaluate_query_conditions(TableName, HeaderList, SelectedColumns, CompleteRow, QueryOperation),
            extract_selected_columns(HeaderList, SelectedColumns, CompleteRow, ResultRow)
        ),
        FilteredData),

    process_tables(RemainingTables, QueryOperation, MoreResults).

% Fetch needed columns
extract_selected_columns(_, all, CompleteRow, CompleteRow) :- !.
extract_selected_columns(_, [], _, []).
extract_selected_columns(HeaderList, [Column | RemainingColumns], CompleteRow, [Value | RemainingValues]) :-
    nth0(ColumnIndex, HeaderList, Column),
    nth0(ColumnIndex, CompleteRow, Value),
    extract_selected_columns(HeaderList, RemainingColumns, CompleteRow, RemainingValues).

% Determine conditions 
evaluate_query_conditions(_, _, _, _, []) :- !.
evaluate_query_conditions(_, _, _, _, [where, []]) :- !.
evaluate_query_conditions(TableName, HeaderList, _, Row, [where, Condition]) :-
    evaluate_condition_tree(TableName, HeaderList, Row, Condition), !.
evaluate_query_conditions(_, _, _, _, [join, _, _]) :- !, fail.
evaluate_query_conditions(_, HeaderList, SelectedColumns, Row, [matches, ValueList]) :-
    extract_selected_columns(HeaderList, SelectedColumns, Row, RowValues),
    member(RowValue, RowValues),
    member(RowValue, ValueList).
evaluate_query_conditions(_, HeaderList1, _, Row1, [matches, Column, SubQuery]) :-
    nth0(ColIndex, HeaderList1, Column),
    nth0(ColIndex, Row1, Value),
    execute_query(SubQuery, FilteredTables),
    findall(SubValue,
        (
            member([_, _, Rows], FilteredTables),
            member(SubRow, Rows),
            nth0(0, SubRow, SubValue)
        ),
        SubValues),
    member(Value, SubValues).

% Execute condititions
evaluate_condition_tree(_, HeaderList, _, [condition, Column, _, _]) :-
    \+ member(Column, HeaderList),
    !, fail.
evaluate_condition_tree(_, HeaderList, Row, [condition, Column, Operator, Value]) :-
    nth0(Index, HeaderList, Column),
    nth0(Index, Row, RowValue),
    compare_typed_values(Operator, RowValue, Value).
evaluate_condition_tree(TableName, HeaderList, Row, [and, Condition1, Condition2]) :-
    evaluate_condition_tree(TableName, HeaderList, Row, Condition1),
    evaluate_condition_tree(TableName, HeaderList, Row, Condition2).
evaluate_condition_tree(TableName, HeaderList, Row, [or, Condition1, Condition2]) :-
    (evaluate_condition_tree(TableName, HeaderList, Row, Condition1);
     evaluate_condition_tree(TableName, HeaderList, Row, Condition2)).

% Convert strings to a different type
convert_string_to_typed_value(StringValue, Converted) :-
    ( helper:is_date(StringValue, Date) ->
        Converted = Date
    ; atom_number(StringValue, Number) ->
        Converted = Number
    ;
        Converted = StringValue
    ).

% Convert values into other values - different from covert string due to date checking
normalize_value(Value, Normalized) :-
    ( number(Value) ->
        Normalized = Value
    ; atom(Value) ->
        atom_string(Value, StringValue),
        convert_string_to_typed_value(StringValue, Normalized)
    ; string(Value) ->
        StringValue = Value,
        convert_string_to_typed_value(StringValue, Normalized)
    ;
        Normalized = Value
    ).

% Performs data comparison
compare_date_values('<', date(Y1, M1, D1), date(Y2, M2, D2)) :-
    date_time_stamp(date(Y1, M1, D1, 0,0,0,0,-,-), T1),
    date_time_stamp(date(Y2, M2, D2, 0,0,0,0,-,-), T2),
    T1 < T2.
compare_date_values('>', date(Y1, M1, D1), date(Y2, M2, D2)) :-
    date_time_stamp(date(Y1, M1, D1, 0,0,0,0,-,-), T1),
    date_time_stamp(date(Y2, M2, D2, 0,0,0,0,-,-), T2),
    T1 > T2.
compare_date_values('=', date(Y1, M1, D1), date(Y2, M2, D2)) :-
    Y1 =:= Y2, M1 =:= M2, D1 =:= D2.

is_date_format(date(_, _, _)).

% Compares values and provides their output 
compare_typed_values(Operator, Value1, Value2) :-
    normalize_value(Value1, NormalizedValue1),
    normalize_value(Value2, NormalizedValue2),
    (
        (number(NormalizedValue1), number(NormalizedValue2)) ->
            (Operator = '<' -> NormalizedValue1 < NormalizedValue2;
            Operator = '>' -> NormalizedValue1 > NormalizedValue2;
            Operator = '=' -> NormalizedValue1 =:= NormalizedValue2)
        ;
        (is_date_format(NormalizedValue1), is_date_format(NormalizedValue2)) ->
            compare_date_values(Operator, NormalizedValue1, NormalizedValue2)
        ;
        (atom(NormalizedValue1), atom(NormalizedValue2), Operator = '=') ->
            NormalizedValue1 = NormalizedValue2
        ;
            fail
    ).

% Entry point
main :-
    current_prolog_flag(argv, [DataFile, PrintOption|_]),
    open(DataFile, read, Stream),
    read_file(Stream,Lines), %Lines contain individual line within the file split by spaces and special character like (,) and (.) .
    close(Stream),
    parse_and_evaluate(PrintOption,Lines,_).