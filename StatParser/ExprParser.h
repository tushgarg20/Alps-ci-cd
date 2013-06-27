#include <string>
#include <vector>
#include <map>
#include <boost/regex.hpp>
#include <boost/lexical_cast.hpp>

class CParser
{
public:
    struct CReader
    {   virtual ~CReader(){}
        virtual bool IsConst(){ return false;}
        virtual bool IsDynamic(){ return false;}
        virtual double Value()=0;
    };
    struct CReaderManager
    {   virtual ~CReaderManager(){}
        virtual CReader* FindReader(std::string)=0;
        virtual std::map<std::string, CReader*> FindRegEx(std::string)=0;
    };
    struct CLocation
    {   std::string file;
        int line;
        CLocation(std::string f, int n) : file(f), line(n) {}
        CLocation(const CLocation& l) : file(l.file), line(l.line) {}
    };
    struct CError : CLocation
    {   std::string message;
        CError(std::string f, int n, std::string s) : CLocation(f, n), message(s) {}
        static bool Cmp(const CError& a, const CError& b){ return a.line<b.line;}
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
    };
    struct CTernaryNode : public CNode // ?:
    {   CNode* N1;
        CNode* N2;
        CNode* N3;
        CTernaryNode(CNode* n1, CNode* n2, CNode* n3) : N1(n1), N2(n2), N3(n3) {}
        ~CTernaryNode(){ delete N1; delete N2; delete N3;}
        double Evaluate();
        CNode* Flatten();
    };
    struct CConstNode : public CNode // numbers
    {   double X;
        CConstNode(double d) : X(d) {}
        double Evaluate(){ return X;}
        bool IsConst(){ return true;}
    };
    struct CVariable : CLocation
    {   std::string name;
        std::map<std::string, bool> dep;
        std::vector<CVariable*> depends;
        std::vector<std::string> formula;
        std::vector<CNode*> expr;
        CReader* reader;
        double value;
        bool bad;
        bool na;
        bool dfs_visited;
        int dfs_done;
        CVariable(std::string f, int n, std::string s) : CLocation(f, n), name(s), bad(false), na(false), value(0), reader(0) {}
    };
    struct CVarNode : public CNode // variables
    {   CVariable* V;
        CVarNode(CVariable* v) : V(v) {}
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
        CDiffNode(CNode* n) : N(n), current(0), old(0) {}
        ~CDiffNode(){ delete N;}
        double Evaluate(){ current=N->Evaluate(); return current-old;}
        void Record(){ old=current;}
        CNode* Flatten();
    };
    struct CList : public CNode
    {   bool IsList(){ return true;}
        CNode* SingleItem(){ return 0;}
        double Evaluate(){ throw 0;}
    };
    struct CVector : public CList
    {   std::vector<CNode*> V;
        CVector(std::vector<CNode*>&v ){ V.swap(v);}
        ~CVector(){ for(unsigned i=0;i<V.size();i++) delete V[i];}
        void Accept(CWalker* W){ for(unsigned i=0;i<V.size();i++) V[i]->Accept(W);}
        CNode* Flatten();
    };
    struct CRegEx : public CLocation
    {   std::string str;
        std::map<std::string, CReader*> map;
        CRegEx(std::string f, int n, std::string s) : CLocation(f, n), str(s) {}
    };
    struct CRegexNode : public CList // regex
    {   CRegEx* R;
        CRegexNode(CRegEx* r) : R(r) {}
        CNode* Flatten();
    };
    struct CDiffList : public CList // D(...)
    {   CParser* P;
        CNode* L;
        CDiffList(CParser* p, CNode* n) : P(p), L(n) {}
        ~CDiffList(){ delete L;}
        CNode* Flatten();
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

    CParser();
    ~CParser();
    void Start(const char*f);
    void Finish();
    void ReadLine(const char*);
    std::vector<CError> CheckDependencies();
    std::vector<CError> BindReader(CReaderManager*);
    bool Defined(const char*s){ return variables.find(s)!=variables.end() && variables[s]->expr.size();}
    bool Ready();
    void Execute();
    int Size(){ return (int) var_list.size();}
    std::string Name(int n){ return var_list[n]->name;}
    double Value(int n){ return var_list[n]->value;}
    double Bad(int n){ return var_list[n]->na;}
    static std::string Clip(std::string);
protected:
    void Throw(std::string s){ throw CError(current_file, formula_line, s);}
    std::string ExpandMacro(std::string);
    void SplitLeft(std::string, std::string&, std::string&);
    void ScanDependencies(CVariable*, std::string);
    void SetFormula(CVariable*, std::string);
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
    CNode* Parse9();    // expr or regex
    CNode* ParseList(); // ,
    void ParseList(std::vector<CNode*>&);

    std::string current_file;
    std::string pending;
    int current_line;
    int formula_line;
    std::map<std::string, std::string> macro;
    std::map<std::string, CVariable*> variables; // definitions
    std::map<std::string, CVariable*> all_vars;
    std::map<std::string, CRegEx*> regexes;
    std::vector<CVariable*> vars;     // evaluation order
    std::vector<CVariable*> var_list; // output order
    std::vector<CVariable*> readers; // output order
    std::vector<CDiffNode*> diffs;
    std::vector<CToken> tokens;
    unsigned token_ptr;
    CVariable* dot;
};
