% function [caStates, ruleTable, executedRules] = runCA(neighbourhood, base, rule, cells, steps, debug)
%
% Joseph Lizier
% 2012
% Distributed under GPLv3 (see distribution of license with the code)
%
% Please cite:
% Joseph T. Lizier, "JIDT: An information-theoretic toolkit for studying the dynamics of complex systems", 2012, https://code.google.com/p/information-dynamics-toolkit/
%
%    Existing sources of memory leakage:
%     - assigning CA(s) = ca <- should copy ca
%     - use of circshift function. Could construct our own vector and copy elements.
%
% This function executes the given 1D (wolfram) cellular automata rule number.
% 
% *NOTE* This function will not work properly with (base)^(base^neighbourhood) > 2^31 - 1
% (e.g. will not work for base 2, neighbourhood 5)
% until the use of long integers can be investigated.
%
% Inputs:
% - neighbourhood - neighbourhood size for the rule (ECA has neighbourhood 3).
%     For an even size neighbourhood (meaning a different number of neighbours on each side of the cell),
%     we take an extra cell from the lower cell indices (i.e. from the left).
% - base - number of discrete states for each cell (for binary states this is 2)
% - rule - supplied as either:
%     a. an integer rule number if <= 2^31 - 1 (Wolfram style; e.g. 110, 54 are the complex ECA rules)
%     b. a HEX string, e.g. phi_par from Mitchell et al. is "0xfeedffdec1aaeec0eef000a0e1a020a0" (note: the leading 0x is not required)
% - cells - number of cells in the CA
% - steps - number of rows to execute the CA for (including the random initial row)
% - debug - turn on various debug messages
% - seed - state input for the random number generator (so one can repeat CA investigations for the same initial state)
%
% Outputs:
% - caStates - a run, from random initial conditions, of a CA of the given parameters.
% - ruleTable - the lookup table for each neighbourhood configuration, constructed from the rule number
% - executedRules - which CA rule was executed for every cell update that occurred for the CA.

function [caStates, ruleTable, executedRules] = runCA(neighbourhood, base, rule, cells, steps, debug, seed)

	% Check arguments:
	if (nargin >= 7)
		rand("state", seed);
	end
	if (nargin < 6)
		debug = false;
	end
	if (nargin < 5)
		steps = 100;
	end
	if (nargin < 4)
		cells = 100;
	end
	if (nargin < 3)
		error("Arguments neighbourhood, base, rule must be supplied");
	end

	% translate the rule into the appropriate base
	ruleTable = zeros(base .^ neighbourhood, 1);
	if (ischar(rule))
		
		% First remove the "0x" from the front of the rule name:
		rule = strrep(rule, "0x", "");
		
		% The rule is specified as a hex string - necessary for larger rule values
		% Check that the rule length is not larger than it should be:
		if (length(rule)*4 > length(ruleTable))
			error(sprintf("Rule specification %s is not within the limits of this base %d and neighbourhood %d (max hex string length is %d)", \
				rule, base, neighbourhood, (base .^ neighbourhood)/4));
		end
		
		for x = length(rule) : -1 :  1
			% Translate each character in the hex string into the 4 rows in the rule table it specifies,
			%  starting from the least significant hex digit:
			hexDigit = rule(x);
			if (strcmp("x", hexDigit))
				% (Can't happen since we removed the 0x already ...)
				% We've reached the end of the hex string
				break;
			end
			thisValue = hex2dec(hexDigit);
			thisValueRemainder = thisValue;
			for i = 4 :-1: 1
				ruleTable((length(rule)-x)*4 + i) = floor(thisValueRemainder ./ base .^ (i-1));
				thisValueRemainder = thisValueRemainder - ruleTable((length(rule)-x)*4 + i) * base .^ (i-1);
				if (debug)
					printf("Rule digit %d: %d, =local %d, local remainder %d\n", (length(rule)-x)*4 + i, \
						ruleTable((length(rule)-x)*4 + i), \
						ruleTable((length(rule)-x)*4 + i) * base .^ (i-1), thisValueRemainder);
				end
			end
			if (thisValueRemainder != 0)
			 	error("Rule %s parsed incorrectly - remainder from hex digit %d is %d\n", rule, x, ruleRemainder);
			end
		end
		printf("Rule %s is: ", rule);
		for i = base .^ neighbourhood : -1 : 1
			printf("%d", ruleTable(i));
		endfor
		printf("\n");
	else
		% The rule is specified as an integer
		if (rule > base .^ (base .^ neighbourhood) - 1)
			error(sprintf("Rule %d is not within the limits of this base %d and neighbourhood %d (max is %d)", \
				rule, base, neighbourhood, base .^ (base .^ neighbourhood) - 1));
		endif
	
		ruleRemainder = rule;
		% printf("Getting %d digits\n", base .^ neighbourhood);
	
		for i = base .^ neighbourhood : -1 : 1
			% Work out digit i
			ruleTable(i) = floor(ruleRemainder ./ base .^ (i-1));
			ruleRemainder = ruleRemainder - ruleTable(i) .* base .^ (i-1);
			if (debug)
				printf("Rule digit %d: %d, =%d, remainder %d\n", i, ruleTable(i), \
					ruleTable(i) .* base .^ (i-1), ruleRemainder);
			endif
		endfor
		if (ruleRemainder != 0)
		 	error("Rule %d parsed incorrectly - remainder is %d\n", rule, ruleRemainder);
		endif
	
		printf("Rule %d is: ", rule);
		for i = base .^ neighbourhood : -1 : 1
			printf("%d", ruleTable(i));
		endfor
		printf("\n");
	end
	
	caStates = zeros(steps, cells);

	% executedRules will store the rules executed at each step of the CA.
	% (we don't need to store this for the last row, since we're not executing the rule update)
	if (nargout >= 3)
		executedRules = zeros(steps - 1, cells);
	end

	% Generate a random start CA
	ca = floor(rand(1, cells) * base);
	
	caStates(1,:) = ca;	
	
	if (debug)
		ca
	endif
	
	for s = 2 : steps
	
		% Compute which rule to update each cell with by effectively constructing the rule number to execute
		%  ie to execute "101" we construct 1* 2^2 + 0 * 2^1 + 1 * 2^0
		% This works
		ruleToRun = zeros(1, cells);
		for i = 1 : neighbourhood
			ruleToRun = ruleToRun + circshift(ca', ceil(-neighbourhood / 2) + (i-1))' .* (base .^ (i-1));
		endfor
		if (nargout >= 3)
			% Save these rule executions:
			executedRules(s - 1, :) = ruleToRun;
		end
		
		if (debug)
			ruleToRun
		endif
		
		% Translate the rules to be run into the updated CA values.
		% Need to add 1 to the ruleToRun because of the indexing starting from 1 not 0.
		ca = ruleTable(ruleToRun + 1)';
		
		if (debug)
			ca
		endif
		
		caStates(s,:) = ca;
	endfor
	
	% CA evolution is done
	if (debug)
		caStates
	endif
endfunction
