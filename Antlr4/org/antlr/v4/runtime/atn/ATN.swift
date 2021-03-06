/*
* [The "BSD license"]
*  Copyright (c) 2012 Terence Parr
*  Copyright (c) 2012 Sam Harwell
*  Copyright (c) 2015 Janyou
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without
*  modification, are permitted provided that the following conditions
*  are met:
*
*  1. Redistributions of source code must retain the above copyright
*     notice, this list of conditions and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright
*     notice, this list of conditions and the following disclaimer in the
*     documentation and/or other materials provided with the distribution.
*  3. The name of the author may not be used to endorse or promote products
*     derived from this software without specific prior written permission.
*
*  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
*  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
*  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
*  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
*  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
*  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


public class ATN {
    public static let INVALID_ALT_NUMBER: Int = 0
    
    
    public final var states: Array<ATNState?> = Array<ATNState?>()
    
    /** Each subrule/rule is a decision point and we must track them so we
     *  can go back later and build DFA predictors for them.  This includes
     *  all the rules, subrules, optional blocks, ()+, ()* etc...
     */
    public final var decisionToState: Array<DecisionState> = Array<DecisionState>()
    
    /**
     * Maps from rule index to starting state number.
     */
    public final var ruleToStartState: [RuleStartState]!
    
    /**
     * Maps from rule index to stop state number.
     */
    public final var ruleToStopState: [RuleStopState]!
    
    
    public final let modeNameToStartState: Dictionary<String, TokensStartState> =  Dictionary<String, TokensStartState>()
    //LinkedHashMap<String, TokensStartState>();
    
    /**
    * The type of the ATN.
    */
    public  let grammarType: ATNType!
    
    /**
     * The maximum value for any symbol recognized by a transition in the ATN.
     */
    public  let maxTokenType: Int
    
    /**
     * For lexer ATNs, this maps the rule index to the resulting token type.
     * For parser ATNs, this maps the rule index to the generated bypass token
     * type if the
     * {@link org.antlr.v4.runtime.atn.ATNDeserializationOptions#isGenerateRuleBypassTransitions}
     * deserialization option was specified; otherwise, this is {@code null}.
     */
    public final var ruleToTokenType: [Int]!
    
    /**
     * For lexer ATNs, this is an array of {@link org.antlr.v4.runtime.atn.LexerAction} objects which may
     * be referenced by action transitions in the ATN.
     */
    public final var lexerActions: [LexerAction]!
    
    public final  var modeToStartState: Array<TokensStartState> = Array<TokensStartState>()
    
    /** Used for runtime deserialization of ATNs from strings */
    public init(_ grammarType: ATNType, _ maxTokenType: Int) {
        self.grammarType = grammarType
        self.maxTokenType = maxTokenType
    }
    
    /** Compute the set of valid tokens that can occur starting in state {@code s}.
     *  If {@code ctx} is null, the set of tokens will not include what can follow
     *  the rule surrounding {@code s}. In other words, the set will be
     *  restricted to tokens reachable staying within {@code s}'s rule.
     */
    public func nextTokens(s: ATNState, _ ctx: RuleContext?)throws -> IntervalSet {
        let anal: LL1Analyzer = LL1Analyzer(self)
        let next: IntervalSet = try anal.LOOK(s, ctx)
        return next
    }
    
    /**
     * Compute the set of valid tokens that can occur starting in {@code s} and
     * staying in same rule. {@link org.antlr.v4.runtime.Token#EPSILON} is in set if we reach end of
     * rule.
     */
    public func nextTokens(s: ATNState) throws -> IntervalSet {
        if  s.nextTokenWithinRule != nil
        {
            return s.nextTokenWithinRule!
        }
        s.nextTokenWithinRule = try nextTokens(s, nil)
        try s.nextTokenWithinRule!.setReadonly(true)
        return s.nextTokenWithinRule!
    }
    
    public func addState(state: ATNState?) {
        if state != nil {
            state!.atn = self
            state!.stateNumber = states.count
        }
        
        states.append(state)
    }
    
    public func removeState(state: ATNState) {
        states[state.stateNumber] = nil
        //states.set(state.stateNumber, nil); // just free mem, don't shift states in list
    }
    
    public func defineDecisionState(s: DecisionState) -> Int {
        decisionToState.append(s)
        s.decision = decisionToState.count-1
        return s.decision
    }
    
    public func getDecisionState(decision: Int) -> DecisionState? {
        if  !decisionToState.isEmpty  {
            return decisionToState[decision]
        }
        return nil
    }
    
    public func getNumberOfDecisions() -> Int {
        return decisionToState.count
    }
    
    /**
     * Computes the set of input symbols which could follow ATN state number
     * {@code stateNumber} in the specified full {@code context}. This method
     * considers the complete parser context, but does not evaluate semantic
     * predicates (i.e. all predicates encountered during the calculation are
     * assumed true). If a path in the ATN exists from the starting state to the
     * {@link org.antlr.v4.runtime.atn.RuleStopState} of the outermost context without matching any
     * symbols, {@link org.antlr.v4.runtime.Token#EOF} is added to the returned set.
     *
     * <p>If {@code context} is {@code null}, it is treated as
     * {@link org.antlr.v4.runtime.ParserRuleContext#EMPTY}.</p>
     *
     * @param stateNumber the ATN state number
     * @param context the full parse context
     * @return The set of potentially valid input symbols which could follow the
     * specified state in the specified context.
     * @throws IllegalArgumentException if the ATN does not contain a state with
     * number {@code stateNumber}
     */
    public func getExpectedTokens(stateNumber: Int, _ context: RuleContext) throws -> IntervalSet {
        if stateNumber < 0 || stateNumber >= states.count {
            throw ANTLRError.IllegalArgument(msg: "Invalid state number.")
            /* throw IllegalArgumentException("Invalid state number."); */
        }
        
        var ctx: RuleContext? = context
        //TODO:  s may be nil
        let s: ATNState = states[stateNumber]!
        var following: IntervalSet = try nextTokens(s)
        if !following.contains(CommonToken.EPSILON) {
            return following
        }
        
        let expected: IntervalSet = try IntervalSet()
        try expected.addAll(following)
        try expected.remove(CommonToken.EPSILON)
        while ctx != nil && ctx!.invokingState >= 0 && following.contains(CommonToken.EPSILON) {
            let invokingState: ATNState = states[ctx!.invokingState]!
            let rt: RuleTransition = invokingState.transition(0) as! RuleTransition
            following = try nextTokens(rt.followState)
            try expected.addAll(following)
            try expected.remove(CommonToken.EPSILON)
            ctx = ctx!.parent
        }
        
        if following.contains(CommonToken.EPSILON) {
            try expected.add(CommonToken.EOF)
        }
        
        return expected
    }
    
    public final func appendDecisionToState(state: DecisionState) {
        decisionToState.append(state)
    }
    public final func appendModeToStartState(state: TokensStartState) {
        modeToStartState.append(state)
    }
    

}
