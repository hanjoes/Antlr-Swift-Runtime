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

import Foundation

public class Recognizer<ATNInterpreter:ATNSimulator> {
    //public  static let EOF: Int = -1
    //TODO: WeakKeyDictionary NSMapTable Dictionary
    private let tokenTypeMapCache: NSMapTable = NSMapTable.weakToWeakObjectsMapTable()

    private let ruleIndexMapCache: NSMapTable = NSMapTable.weakToWeakObjectsMapTable()


    private var _listeners: Array<ANTLRErrorListener> = [ConsoleErrorListener.INSTANCE]


    public var _interp: ATNInterpreter!

    private var _stateNumber: Int = -1

    /** Used to print out token names like ID during debugging and
     *  error reporting.  The generated parsers implement a method
     *  that overrides this to point to their String[] tokenNames.
     *
     * @deprecated Use {@link #getVocabulary()} instead.
     */
    ////@Deprecated
    public func getTokenNames() -> [String?]? {
        RuntimeException(#function + " must be overridden")
        return []
    }

    public func getRuleNames() -> [String] {
        RuntimeException(#function + " must be overridden")
        return []
    }


    /**
     * Get the vocabulary used by the recognizer.
     *
     * @return A {@link org.antlr.v4.runtime.Vocabulary} instance providing information about the
     * vocabulary used by the grammar.
     */

    public func getVocabulary() -> Vocabulary {
        return Vocabulary.fromTokenNames(getTokenNames())
    }

    /**
     * Get a map from token names to token types.
     *
     * <p>Used for XPath and tree pattern compilation.</p>
     */
    public func getTokenTypeMap() -> Dictionary<String, Int> {
        let vocabulary: Vocabulary = getVocabulary()
        var result: Dictionary<String, Int>? = self.tokenTypeMapCache[vocabulary] as? Dictionary<String, Int>
        synced(tokenTypeMapCache) {
            [unowned self] in
            if result == nil {
                result = Dictionary<String, Int>()
                let length = self.getATN().maxTokenType
                for i in 0..<length {
                    let literalName: String? = vocabulary.getLiteralName(i)
                    if literalName != nil {
                        result![literalName!] = i
                    }

                    let symbolicName: String? = vocabulary.getSymbolicName(i)
                    if symbolicName != nil {
                        result![symbolicName!] = i
                    }
                }

                result!["EOF"] = CommonToken.EOF

                //TODO Result Collections.unmodifiableMap

                self.tokenTypeMapCache[vocabulary] = result!
            }


        }
        return result!

    }

    /**
     * Get a map from rule names to rule indexes.
     *
     * <p>Used for XPath and tree pattern compilation.</p>
     */
    public func getRuleIndexMap() -> Dictionary<String, Int> {
        let ruleNames: [String] = getRuleNames()

        let result: Dictionary<String, Int>? = self.ruleIndexMapCache[ruleNames] as? Dictionary<String, Int>
        synced(ruleIndexMapCache) {
            [unowned self] in
            if result == nil {

                self.ruleIndexMapCache[ruleNames] = result
            }

        }
        return result!

    }

    public func getTokenType(tokenName: String) -> Int {
        let ttype: Int? = getTokenTypeMap()[tokenName]
        if ttype != nil {
            return ttype!
        }
        return CommonToken.INVALID_TYPE
    }

    /**
     * If this recognizer was generated, it will have a serialized ATN
     * representation of the grammar.
     *
     * <p>For interpreters, we don't know their serialized ATN despite having
     * created the interpreter from it.</p>
     */
    public func getSerializedATN() -> String {
        RuntimeException("there is no serialized ATN")
        fatalError()
        ///throw  ANTLRError.UnsupportedOperation /* throw UnsupportedOperationException("there is no /serialized ATN"); */
    }

    /** For debugging and other purposes, might want the grammar name.
     *  Have ANTLR generate an implementation for this method.
     */
    public func getGrammarFileName() -> String {
        RuntimeException(#function + " must be overridden")
        return ""
    }

    /**
     * Get the {@link org.antlr.v4.runtime.atn.ATN} used by the recognizer for prediction.
     *
     * @return The {@link org.antlr.v4.runtime.atn.ATN} used by the recognizer for prediction.
     */
    public func getATN() -> ATN {
        RuntimeException(#function + " must be overridden")
        fatalError()
    }

    /**
     * Get the ATN interpreter used by the recognizer for prediction.
     *
     * @return The ATN interpreter used by the recognizer for prediction.
     */
    public func getInterpreter() -> ATNInterpreter {
        return _interp
    }

    /** If profiling during the parse/lex, this will return DecisionInfo records
     *  for each decision in recognizer in a ParseInfo object.
     *
     * @since 4.3
     */
    public func getParseInfo() -> ParseInfo? {
        return nil
    }

    /**
     * Set the ATN interpreter used by the recognizer for prediction.
     *
     * @param interpreter The ATN interpreter used by the recognizer for
     * prediction.
     */
    public func setInterpreter(interpreter: ATNInterpreter) {
        _interp = interpreter
    }

    /** What is the error header, normally line/character position information? */
    //public func getErrorHeader(e : RecognitionException

    public func getErrorHeader(e: AnyObject) -> String {
        let line: Int = (e as! RecognitionException).getOffendingToken().getLine()
        let charPositionInLine: Int = (e as! RecognitionException).getOffendingToken().getCharPositionInLine()
        return "line " + String(line) + ":" + String(charPositionInLine)
    }

    /** How should a token be displayed in an error message? The default
     *  is to display just the text, but during development you might
     *  want to have a lot of information spit out.  Override in that case
     *  to use t.toString() (which, for CommonToken, dumps everything about
     *  the token). This is better than forcing you to override a method in
     *  your token objects because you don't have to go modify your lexer
     *  so that it creates a new Java type.
     *
     * @deprecated This method is not called by the ANTLR 4 Runtime. Specific
     * implementations of {@link org.antlr.v4.runtime.ANTLRErrorStrategy} may provide a similar
     * feature when necessary. For example, see
     * {@link org.antlr.v4.runtime.DefaultErrorStrategy#getTokenErrorDisplay}.
     */
    ////@Deprecated
    public func getTokenErrorDisplay(t: Token?) -> String {
        if t == nil {
            return "<no token>"
        }
        var s: String? = t!.getText()
        if s == nil {
            if t!.getType() == CommonToken.EOF {
                s = "<EOF>"
            } else {
                s = "<\(t!.getType())>"
            }
        }

        s = s!.replaceAll("\n", replacement: "\\n")
        s = s!.replaceAll("\r", replacement: "\\r")
        s = s!.replaceAll("\t", replacement: "\\t")
        return "\(s)"
    }

    /**
     * @exception NullPointerException if {@code listener} is {@code null}.
     */
    public func addErrorListener(listener: ANTLRErrorListener) {

        _listeners.append(listener)
    }

    public func removeErrorListener(listener: ANTLRErrorListener) {
        _listeners = _listeners.filter() {
            $0 !== listener
        }

        // _listeners.removeObject(listener);
    }

    public func removeErrorListeners() {
        _listeners.removeAll()
    }


    public func getErrorListeners() -> Array<ANTLRErrorListener> {
        return _listeners
    }

    public func getErrorListenerDispatch() -> ANTLRErrorListener {
        return ProxyErrorListener(getErrorListeners())
    }

    // subclass needs to override these if there are sempreds or actions
    // that the ATN interp needs to execute
    public func sempred(_localctx: RuleContext?, _ ruleIndex: Int, _ actionIndex: Int) throws -> Bool {
        return true
    }

    public func precpred(localctx: RuleContext?, _ precedence: Int) throws -> Bool {
        return true
    }

    public func action(_localctx: RuleContext?, _ ruleIndex: Int, _ actionIndex: Int) throws {
    }

    public final func getState() -> Int {
        return _stateNumber
    }

    /** Indicate that the recognizer has changed internal state that is
     *  consistent with the ATN state passed in.  This way we always know
     *  where we are in the ATN as the parser goes along. The rule
     *  context objects form a stack that lets us see the stack of
     *  invoking rules. Combine this and we have complete ATN
     *  configuration information.
     */
    public final func setState(atnState: Int) {
//		System.err.println("setState "+atnState);
        _stateNumber = atnState
//		if ( traceATNStates ) _ctx.trace(atnState);
    }

    public func getInputStream() -> IntStream? {
        RuntimeException(#function + "Must be overridden")
        fatalError()
    }


    public func setInputStream(input: IntStream) throws {
        RuntimeException(#function + "Must be overridden")

    }


    public func getTokenFactory() -> TokenFactory {
        RuntimeException(#function + "Must be overridden")
        fatalError()
    }


    public func setTokenFactory(input: TokenFactory) {
        RuntimeException(#function + "Must be overridden")

    }

}
