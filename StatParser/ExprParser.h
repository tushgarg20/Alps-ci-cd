#include <string>
#include <vector>
#include <map>
#include <set>
#include <boost/regex.hpp>
#include <boost/lexical_cast.hpp>

class CParser
{
public:
    struct CReader
    {   virtual ~CReader(){}
        virtual bool IsConst(){ return false;}
        virtual bool IsDefault(){ return false;}
        virtual bool IsDynamic(){ return false;}
        virtual double Value()=0;
    };
    struct CDynamicReader : public CReader
    {   virtual ~CDynamicReader(){}
        bool IsDynamic(){ return true;}
        virtual void Set(double)=0;
    };
    struct CReaderManager
    {   virtual ~CReaderManager(){}
        virtual CReader* FindReader(std::string)=0;
        virtual std::vector<std::vector<std::string> > MatchPattern(std::string)=0;
        virtual std::vector<CReader*> FindRegExAsVector(std::string)=0;
        virtual std::map<std::string, CReader*> FindRegExAsMap(std::string)=0;
        virtual void ExportGlobal(std::string){}
    };
    struct CLocation
    {   std::string file;
        int line;
        CLocation(std::string f, int n) : file(f), line(n) {}
        CLocation(const CLocation& l) : file(l.file), line(l.line) {}
    };
    struct CError : CLocation
    {   std::string var;
        std::string message;
        CError(std::string f, int n, std::string v, std::string s) : CLocation(f, n), var(v), message(s) {}
        static bool Cmp(const CError& a, const CError& b){ return a.line<b.line;}
    };
    struct CLine : CLocation
    {   std::string str;
        std::string pattern;
        std::string right;
        std::string left;
        bool plus_eq;
        CLine(std::string f, int n, std::string s, std::string p, std::string r, std::string l, bool q) : CLocation(f, n), str(s), pattern(p), right(r), left(l), plus_eq(q) {}
    };
    enum TOKEN
    {   ERR,
        NAME,
        NUM,
        REGEX,
        PLUS,   // +
        MINUS,  // -
        MUL,    // *
        DIV,    // /
        MOD,    // %
        EQ,     // ==
        NE,     // !=
        GT,     // >
        LT,     // <
        GTE,    // >=
        LTE,    // <=
        NOT,    // !
        AND,    // &&
        OR,     // ||
        OPEN,   // (
        CLOSE,  // )
        BRA,    // [
        KET,    // ]
        COMMA,  // ,
        QUEST,  // ?
        COLON   // :
    };
    struct CToken
    {   TOKEN type;
        double num;
        std::string str;
        CToken(TOKEN t, std::string s) : type(t), str(s) {}
        CToken(TOKEN t, std::string s, double d) : type(t), str(s), num(d) {}
    };
    struct CWalker;
    struct CNode
    {   virtual ~CNode(){}
        virtual double Evaluate()=0;
        virtual bool IsConst(){ return false;}
        virtual bool IsList(){ return false;}
        virtual bool IsEmpty(){ return false;}
        virtual void Accept(CWalker* w){ w->Visit(this);}
        virtual CNode* Flatten(){ return this;}
        CNode* Scalar();
        virtual void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this);}
    };
    struct CEmptyNode : public CNode
    {   double Evaluate(){ throw 0;}
        bool IsEmpty(){ return true;}
        void Accept(CWalker* w){}
    };
    struct CUnaryNode : public CNode // ! -
    {   enum TYPE { NOT, MINUS };
        TYPE T;
        CNode* N;
        CUnaryNode(TYPE t, CNode* n) : T(t), N(n) {}
        ~CUnaryNode(){ delete N;}
        double Evaluate();
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); N->Recursion(func, P);}
    };
    struct CBinaryNode : public CNode // + - * / % == != < > <= >= && ||
    {   enum TYPE { PLUS, MINUS, MUL, DIV, MOD, EQ, NE, LT, GT, LTE, GTE, AND, OR };
        TYPE T;
        CNode* N1;
        CNode* N2;
        CBinaryNode(TYPE t, CNode* n1, CNode* n2) : T(t), N1(n1), N2(n2) {}
        ~CBinaryNode(){ delete N1; delete N2;}
        double Evaluate();
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); N1->Recursion(func, P); N2->Recursion(func, P);}
    };
    struct CTernaryNode : public CNode // ?:
    {   CNode* N1;
        CNode* N2;
        CNode* N3;
        CTernaryNode(CNode* n1, CNode* n2, CNode* n3) : N1(n1), N2(n2), N3(n3) {}
        ~CTernaryNode(){ delete N1; delete N2; delete N3;}
        double Evaluate();
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); N1->Recursion(func, P); N2->Recursion(func, P); N3->Recursion(func, P);}
    };
    struct CConstNode : public CNode // numbers
    {   double X;
        CConstNode(double d) : X(d) {}
        double Evaluate(){ return X;}
        bool IsConst(){ return true;}
    };
    struct CVariable : CLocation
    {   std::string name;
        std::vector<CVariable*> depends;
        std::vector<std::string> formula;
        std::vector<CNode*> expr;
        std::vector<double> history;
        std::vector<bool> nahistory;
        uint32_t size;
        CReader* reader;
        double value;
        bool bad;
        bool na;
        bool dfs_visited;
        int dfs_done;
        CVariable(std::string f, int n, std::string s) : CLocation(f, n), name(s), bad(false), na(false), value(0), reader(0), size(0) {}
        ~CVariable(){ for(size_t i=0;i<expr.size();i++) delete expr[i];}
        void UpdateHistory();
    };
    struct CVarNode : public CNode // variables
    {   CVariable* V;
        uint32_t T;
        CVarNode(CVariable* v, uint32_t t=0) : V(v), T(t) { if(V->size<t) V->size=T; }
        double Evaluate();
        CNode* Flatten();
    };
    struct CReaderNode : public CNode
    {   CReader* R;
        CReaderNode(CReader* r) : R(r) {}
        double Evaluate(){ return R->Value();}
    };
    struct CDiffNode : public CNode // D(...)
    {   CNode* N;
        double current;
        double old;
        bool current_na;
        bool old_na;
        CDiffNode(CNode* n) : N(n), current(0), old(0), current_na(false), old_na(false) {}
        ~CDiffNode(){ delete N;}
        double Evaluate(){ current_na=true; current=N->Evaluate(); current_na=false; if(old_na) throw 0; return current-old;}
        void Record(){ old=current; old_na=current_na;}
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); N->Recursion(func, P);}
    };
    struct CList : public CNode
    {   bool IsList(){ return true;}
        double Evaluate(){ throw 0;}
    };
    struct CVector : public CList
    {   std::vector<CNode*> V;
        CVector(std::vector<CNode*>&v ){ V.swap(v);}
        ~CVector(){ for(uint32_t i=0;i<V.size();i++) delete V[i];}
        void Accept(CWalker* W){ for(uint32_t i=0;i<V.size();i++) V[i]->Accept(W);}
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); for(uint32_t i=0;i<V.size();i++) V[i]->Recursion(func, P);}
    };
    struct CRegEx : public CLocation
    {   std::string str;
        std::map<std::string, CReader*> map;
        std::vector<CReader*> vector;
        bool is_map;
        CRegEx(std::string f, int n, std::string s) : CLocation(f, n), str(s), is_map(false) {}
    };
    struct CRegexNode : public CList // regex
    {   CRegEx* R;
        CRegexNode(CRegEx* r) : R(r) {}
        CNode* Flatten();
    };
    struct CDiffList : public CList // D(...)
    {   CNode* L;
        CDiffList(CNode* n) : L(n) {}
        ~CDiffList(){ delete L;}
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); L->Recursion(func, P);}
    };
    struct CMemList : public CList // var[...]
    {   CVariable* V;
        CNode* L;
        CMemList(CVariable* v, CNode* n) : V(v), L(n) {}
        ~CMemList(){ delete L;}
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); L->Recursion(func, P);}
    };
    struct CRangeNode : public CList // a : b
    {   CNode* N1;
        CNode* N2;
        CRangeNode(CNode* n1, CNode* n2) : N1(n1), N2(n2) {}
        ~CRangeNode(){ delete N1; delete N2;}
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); N1->Recursion(func, P); N2->Recursion(func, P);}
    };
    struct CWalker : public CNode // function call
    {   CNode* L;
        double value;
        CWalker(CNode* n) : L(n), value(0) {}
        ~CWalker(){ delete L;}
        virtual void StartWalk(){ value=0;}
        virtual double FinishWalk(){ return value;}
        virtual double Evaluate(){ StartWalk(); L->Accept(this); return FinishWalk();}
        virtual void Visit(CNode*)=0;
        CNode* Flatten();
        void Recursion(void (*func)(CParser*, CNode*), CParser*P){ func(P, this); L->Recursion(func, P);}
    };
    struct CSumNode : public CWalker
    {   CSumNode(CNode* n) : CWalker(n) {}
        void Visit(CNode* n){ value+=n->Evaluate();}
    };
    struct CMinNode : public CWalker
    {   bool empty;
        CMinNode(CNode* n) : CWalker(n), empty(true) {}
        void StartWalk(){ empty=true;}
        void Visit(CNode* n){ double d=n->Evaluate(); if(empty || d<value) value=d; empty=false;}
        double FinishWalk(){ if(empty) throw 0; return value;}
    };
    struct CMaxNode : public CWalker
    {   bool empty;
        CMaxNode(CNode* n) : CWalker(n), empty(true) {}
        void StartWalk(){ empty=true;}
        void Visit(CNode* n){ double d=n->Evaluate(); if(empty || d>value) value=d; empty=false;}
        double FinishWalk(){ if(empty) throw 0; return value;}
    };
    struct CAvgNode : public CWalker
    {   int cnt;
        CAvgNode(CNode* n) : CWalker(n) {}
        void StartWalk(){ cnt=0; value=0;}
        void Visit(CNode* n){ value+=n->Evaluate(); cnt++;}
        double FinishWalk(){ if(!cnt) throw 0; return value/cnt;}
    };
    struct CCountNode : public CWalker
    {   CCountNode(CNode* n) : CWalker(n) {}
        void Visit(CNode* n){ value++;}
    };
    struct CBinNode : public CWalker
    {   bool first;
        bool empty;
        double x;
        double last;
        CBinNode(CNode* n) : CWalker(n) {}
        void StartWalk(){ first=true; value=0;}
        void Visit(CNode* n);
    };
    struct CCaseNode : public CWalker
    {   bool first;
        bool empty;
        int count;
        CCaseNode(CNode* n) : CWalker(n) {}
        void StartWalk(){ first=true; empty=true;}
        void Visit(CNode* n);
        double FinishWalk(){ if(empty) throw 0; return value;}
    };
    struct CReport : public CLocation
    {   CReport(std::string f, int n) : CLocation(f, n) {}
        virtual size_t Size() const = 0;
        virtual std::string Name(size_t) const = 0;
        virtual double Value(size_t) const = 0;
        virtual bool Bad(size_t) const = 0;
    };
    class CPlainVariable : public CReport
    {   CVariable*V;
    public:
        CPlainVariable(CVariable*v) : CReport(v->file, v->line), V(v) {}
        size_t Size() const { return 1;}
        std::string Name(size_t) const { return V->name;}
        double Value(size_t) const { return V->value;}
        bool Bad(size_t) const { return V->na;}
    };
    class CPassThroughVariable : public CReport
    {   std::string name;
        CReader* R;
    public:
        CPassThroughVariable(std::string s, std::string f, int n) : CReport(f, n), name(s), R(0) {}
        size_t Size() const { return 1;}
        std::string Name(size_t) const { return name;}
        double Value(size_t) const { return R->Value();}
        bool Bad(size_t) const { return !R;}
        friend class CParser;
    };
    class CPassThroughRegex : public CReport
    {   std::string pref;
        std::string rex;
        std::vector<CReader*> readers;
        std::vector<std::string> names;
        std::vector<double> old_val;
        std::vector<double> new_val;
        std::vector<double> value;
        bool diff;
    public:
        CPassThroughRegex(std::string p, std::string r, bool d, std::string f, int n) : CReport(f, n), pref(p), rex(r), diff(d) {}
        size_t Size() const { return names.size();}
        std::string Name(size_t n) const { return pref+names[n];}
        double Value(size_t n) const { return value[n];}
        bool Bad(size_t) const { return false;}
        void Update(){ for(uint32_t i=0;i<readers.size();i++){ if(diff) old_val[i]=new_val[i]; new_val[i]=readers[i]->Value(); value[i]=diff?new_val[i]-old_val[i]:new_val[i];}}
        friend class CParser;
    };

    CParser();
    ~CParser();
    void Start(const char*f);
    void Finish();
    void ReadLine(const char*);
    std::vector<CError> CheckDependencies();
    std::vector<CError> Initialize(CReaderManager*);
    std::vector<CError> BindReader(CReaderManager*);
    bool Defined(const char*s){ return variables.find(s)!=variables.end() && variables[s]->expr.size();}
    void Define(std::string name, std::string expr){ DefineVariable(name, expr, false, "", 0);}    // may throw exception
    bool Ready();
    void Execute();
    size_t Size(){ return var_list.size();}
    const CReport* Report(size_t n){ return var_list[n];}
    static std::string Clip(std::string);
protected:
    static void CollectDiffs(CParser*, CNode*);
    static bool InvalidRegex(std::string);
    static void ScanDependencies(CParser*, CNode*);
    void Throw(std::string s){ throw CError(current_file, formula_line, current_var, s);}
    void DefineVariable(std::string name, std::string expr, bool plus_eq, std::string file, int line);
    static std::string SubstituteSubpatterns(std::string, const std::vector<std::string>&);
    std::string ExpandMacro(std::string);
    void SplitLeft(std::string, std::string&, std::string&);
    static bool dfs_sort(CVariable*a, CVariable*b){ return a->dfs_done<b->dfs_done;}
    CNode* Parse(std::string);
    void Tokenize(std::string);
    CNode* Parse0();    // const, var, func, ()
    CNode* Parse1();    // ! -
    CNode* Parse2();    // * /
    CNode* Parse3();    // + -
    CNode* Parse4();    // < > <= >=
    CNode* Parse5();    // == !=
    CNode* Parse6();    // &&
    CNode* Parse7();    // ||
    CNode* Parse8();    // ?:
    CNode* Parse9();    // expr or regex or range
    CNode* ParseRange();// a:b
    CNode* ParseList(); // ,
    void ParseList(std::vector<CNode*>&);

    std::string current_file;
    std::string current_var;
    std::string pending;
    int current_line;
    int formula_line;
    std::vector<CLine*> lines;
    std::map<std::string, std::string> macro;
    std::map<std::string, CVariable*> variables; // definitions
    std::map<std::string, CVariable*> all_vars;
    std::map<std::string, bool> defined_names;
    std::map<std::string, CRegEx*> regexes;
    std::vector<CVariable*> dynamic;
    std::vector<CVariable*> history;
    std::vector<CVariable*> vars;     // evaluation order
    std::vector<CReport*> var_list;   // output order
    std::vector<CPassThroughVariable*> p_t_vars;   // pass through variables
    std::vector<CPassThroughRegex*> p_t_regs;   // pass through regexes
    std::vector<CDiffNode*> diffs;
    std::vector<CToken> tokens;
    std::set<CVariable*> dep;
    uint32_t token_ptr;
    CVariable* dot;
};
