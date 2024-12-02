:- [facts].
:- [helper].


%replace "fail" for your solution. It is simply a placeholder to avoid binding for the starter code.
nlp_parse(LineSplit,Query):- fail.
evaluate_logical(Query,FilteredTable):- fail.

% Parse individual commands and evaluate
parse_and_evaluate(_,[], []).
parse_and_evaluate(part1,[[_,LineSplit]|T], [Query|ResultTail]):-
                nlp_parse(LineSplit,Query),
                write(Query),nl,
                parse_and_evaluate(part1,T,ResultTail).

parse_and_evaluate(part2,[[Line,LineSplit]|T], [Result|ResultTail]):-
                write(Line),nl,
                nlp_parse(LineSplit,Query),
                evaluate_logical(Query,FilteredTable),
                %write("\t"),write(FilteredTable),nl,
                print_tables(FilteredTable),
                parse_and_evaluate(part2,T,ResultTail).

%ADD YOUR OTHER CODE HERE (note from alex)

% 'Get' is in single quotes because the string actually starts with an
% upper case and its not meant ot be used as a variable
command([command, TableColumnInfo, CommandOperation]) --> ['Get'], tableColumnInfo(TableColumnInfo), commandOperation(CommandOperation).

tableColumnInfo([TableColumnDetail]) --> tableColumnDetail(TableColumnDetail).
% Use pipe instead of comma because it acts like a list for inputs
tableColumnInfo([TableColumnDetail | TableColumnInfo]) --> tableColumnDetail(TableColumnDetail), [and], tableColumnInfo(TableColumnInfo).

tableColumnDetail(...) --> [all], [from], table(Table).
tableColumnDetail(...) -->  columns(Columns), [from], table(Table).

commandOperation(...) --> joinOperation(JoinOperation).
commandOperation(...) --> matchOperation(MatchOperation).
commandOperation(...) --> whereOperation(WhereOperation).

joinOperation(...) --> [linking], table(Table), [by], [their], col(Col).
joinOperation(...) --> [connecting], table(Table), [by], [their], col(Col).

matchOperation(...) --> [such], [that], matchCondition(MatchCondition).

matchCondition(...) --> [its], [values], [are], [either], values(Values).
% since there are 2 instances of col(Col) you may want to make them
% col(Col1) and col(Col2)
matchCondition(...) --> col(Co1l), [matches], [values], [within], [the], col(Col2), [in], table(Table), whereOperation(WhereOperation).

%whereOperation(...) --> ??? I NEED HELP FOR THIS since it uses {}

orCondition(...) --> condition(Condition).
% since we have 2 instances of condition(Condition), we may need to do
% condition(Condition1) and condition(Condition2)
orCondition(...) --> [either], condition(Condition1), [or], condition(Condition2).

condition(...) --> col(Col), equality(Equality), val(Val).

equality(...) --> [is], [less], [than].
equality(...) --> [is], [greater], [than].
equality(...) --> [equals].

table(Table) --> [Table].

%columns(...) --> I need help since it uses {}
% REMEMBER IN CASES WITH {} THIS MEANS YOU MUST DEFINE RECURSIVE
% FUNCTION. YOU NEED BASE CASE WHERE INPUT IS [], a single variable, and
% then other stuff + the recursive call

col(Col) --> [Col].

%values(...) --> I need help since it uses {}

val(Val) --> [Val].


% Main
main :-
    current_prolog_flag(argv, [DataFile, PrintOption|_]),
    open(DataFile, read, Stream),
    read_file(Stream,Lines), %Lines contain individual line within the file split by spaces and special character like (,) and (.) .
    close(Stream),
	parse_and_evaluate(PrintOption,Lines,_).
