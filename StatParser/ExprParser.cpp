#include <iostream>
#include <fstream>
#include <stdint.h>
#include "ExprParser.h"

static char* AlphaNumDot="._0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

CParser::CParser()
{
    dot=new CVariable("", 0, ".");
    all_vars["."]=dot; vars.push_back(dot);
}

CParser::~CParser()
{   for(std::map<std::string, CVariable*>::iterator J=all_vars.begin();J!=all_vars.end();J++) delete J->second;
    for(std::map<std::string, CRegEx*>::iterator J=regexes.begin();J!=regexes.end();J++) delete J->second;
    for(unsigned i=0;i<var_list.size();i++) delete var_list[i];
}

void CParser::Start(const char*f){ Finish(); current_file=f; current_line=0; formula_line=0; pending.erase();}
void CParser::Finish(){ if(pending.length()){ pending.erase(); Throw("unexpected end of file");}}

void CParser::ReadLine(const char*str)
{   int n;
    std::string s=str;
    current_line++;
    current_var.erase();
    if(pending.empty()) formula_line=current_line;
    n=s.find('#'); if(n!=std::string::npos) s=s.substr(0, n);
    s=Clip(s);
    s=pending+s;
    if(s.empty()) return;
    if(s[s.length()-1]=='\\')
    {   pending=s.substr(0, s.length()-1);
        return;
    }
    pending.clear();
    n=s.find('=');
    if(n==std::string::npos)
    {   Throw(std::string("syntax error: ")+s);
    }
    std::string left=Clip(s.substr(0, n));
    std::string right=ExpandMacro(Clip(s.substr(n+1)));
    if(boost::regex_match(left, boost::regex("^@[\\w]+@$")))
    {   macro[left]=right;
        return;
    }
    if(boost::regex_match(left, boost::regex("^\\S*\\s*\\(\\S*\\)$")))
    {   n=left.find_first_of(" \t(");
        left=left.substr(0, n);
    }
    if(boost::regex_match(left, boost::regex("^[^\']*\'[^\']+\'$")))
    {   n=left.find_first_of('\'');
        std::string pref=left.substr(0, n);
        std::string rex=left.substr(n);
        if(right!=rex && right !=std::string("D")+rex) Throw(std::string("invalid expression: ")+right);
        if(defined_names.find(left)!=defined_names.end()) Throw(std::string("name redefinition: ")+left);
        defined_names[left]=true;
        bool diff=(right!=rex);
        rex=rex.substr(1, rex.length()-2);
        CPassThroughRegex* P=new CPassThroughRegex(pref, rex, diff, current_file, formula_line);
        var_list.push_back(P); p_t_regs.push_back(P);
        return;
    }

    if(!boost::regex_match(left, boost::regex("^\\.?[a-zA-Z_][\\w\\.]*$|^\\.$"))) Throw(std::string("invalid name: ")+left);
    if(defined_names.find(left)!=defined_names.end()) Throw(std::string("name redefinition: ")+left);
    defined_names[left]=true;
    if(left==right)
    {   CPassThroughVariable* P=new CPassThroughVariable(left, current_file, formula_line);
        var_list.push_back(P); p_t_vars.push_back(P);
        return;
    }

    CVariable* V = all_vars.find(left)==all_vars.end() ? new CVariable(current_file, formula_line, left) : all_vars[left];
    V->file=current_file; V->line=formula_line;
    variables[left]=V; all_vars[left]=V;
    if(V!=dot){ vars.push_back(V); var_list.push_back(new CPlainVariable(V));}
    current_var=V->name;
    ScanDependencies(V, right);
    SetFormula(V, right);
    V->bad=true; V->na=true;
    for(unsigned i=0;i<V->formula.size();i++) V->expr.push_back(Parse(V->formula[i]));
    V->bad=false; V->na=false;
}

std::string CParser::Clip(std::string s)
{   int n=s.find_first_not_of(" \t\n\r");
    if(n==std::string::npos) return "";
    s=s.substr(n);
    n=s.find_last_not_of(" \t\n\r");
    if(n!=std::string::npos) s=s.substr(0, n+1);
    return s;
}

std::string CParser::ExpandMacro(std::string s)
{   for(int n=s.find('@');n!=std::string::npos;n=s.find('@'))
    {   int k=s.find('@', n+1);
        if(k==std::string::npos) Throw("unmatched @");
        std::string key=s.substr(n, k-n+1);
        if(macro.find(key)==macro.end())
        {   Throw(std::string("undefined macro: ")+key);
        }
        s=s.substr(0, n)+macro[key]+s.substr(k+1);
    }
    return s;
}

void CParser::ScanDependencies(CVariable*V, std::string s)
{   for(int n=s.find('\'');n!=std::string::npos;n=s.find('\''))
    {   int k=s.find('\'', n+1);
        if(k==std::string::npos) Throw("unmatched quote");
        s=s.substr(0, n)+s.substr(k+1);
    }
    for(int n=s.find_first_of(AlphaNumDot);n!=std::string::npos;n=s.find_first_of(AlphaNumDot))
    {   int k=s.find_first_not_of(AlphaNumDot, n+1);
        if(k!=std::string::npos)
        {   int m=s.find_first_not_of(" \t", k);
            if(s[m]=='['){ s=s.substr(m+1); continue;}
        }
        std::string ddd=s.substr(n, k==std::string::npos?k:k-n);
        if(!boost::regex_match(ddd, boost::regex("^[\\.\\d]+$"))) V->dep[ddd]=true;
        if(k==std::string::npos) break;
        s=s.substr(k+1);
    }
}

void CParser::SetFormula(CVariable*V, std::string s)
{   for(int n=s.find("?=");n!=std::string::npos;n=s.find("?="))
    {   V->formula.push_back(Clip(s.substr(0, n)));
        s=s.substr(n+2);
    }
    V->formula.push_back(Clip(s));
}

std::vector<CParser::CError> CParser::CheckDependencies()
{   std::vector<CParser::CError> Err;
    for(unsigned i=0;i<vars.size();i++)
    {   CVariable* v=vars[i];
        for(std::map<std::string, bool>::iterator J=v->dep.begin();J!=v->dep.end();J++)
        {   if(variables.find(J->first)==variables.end()) continue;
            CVariable*u=variables[J->first];
            if(u==v)
            {   v->bad=true; v->na=true;
                Err.push_back(CError(v->file, v->line, v->name, std::string("circular dependency: ")+v->name+" <= "+v->name));
                break;
            }
            v->depends.push_back(u);
        }
        v->dep.clear(); // don't need it any longer
        v->dfs_visited=false;
    }
    int count=0;
    std::vector<CVariable*> stack;
    for(unsigned i=0;i<vars.size();i++)
    {   CVariable*v=vars[i];
        if(v->dfs_visited) continue;
        v->dfs_visited=true;
        stack.push_back(v);
        while(stack.size())
        {   CVariable* x=stack.back();
            CVariable* z=0;
            for(unsigned i=0;i<x->depends.size();i++)
            {   if(x->depends[i]->dfs_visited) continue;
                z=x->depends[i];
                break;
            }
            if(z)
            {   z->dfs_visited=true;
                stack.push_back(z);
            }
            else
            {   x->dfs_done=count++;
                stack.pop_back();
            }
        }
    }
    std::sort(vars.begin(), vars.end(), dfs_sort);
    for(unsigned i=0;i<vars.size();i++) vars[i]->dfs_visited=false;
    for(unsigned i=0;i<vars.size();i++)
    {   CVariable*v=vars[i];
        if(v->dfs_visited) continue;
        v->dfs_visited=true;
        stack.push_back(v);
        std::vector<CVariable*> cycle;
        while(stack.size())
        {   CVariable* x=stack.back();
            CVariable* z=0;
            for(unsigned i=0;i<x->depends.size();i++)
            {   if(x->depends[i]->dfs_visited) continue;
                z=x->depends[i];
                break;
            }
            if(z)
            {   z->dfs_visited=true;
                stack.push_back(z);
                cycle.push_back(z);
            }
            else
            {   stack.pop_back();
            }
        }
        if(cycle.size())
        {   std::string msg;
            for(unsigned j=0;j<cycle.size();j++)
            {   msg+=cycle[j]->name+" <= ";
                cycle[j]->bad=true;
                cycle[j]->na=true;
            }
            v->bad=true; v->na=true;
            Err.push_back(CError(v->file, v->line, v->name, std::string("circular dependency: ")+v->name+" <= "+msg+v->name));
        }
    }
    return Err;
}

void CParser::Tokenize(std::string s)
{   tokens.clear();
    for(unsigned i=0;i<s.length();i++)
    {   char c=s[i];
        if(c==' '||c=='\t') continue;
        if(c=='+'){ tokens.push_back(CToken(PLUS, "+")); continue;}
        if(c=='-'){ tokens.push_back(CToken(MINUS, "-")); continue;}
        if(c=='*'){ tokens.push_back(CToken(MUL, "*")); continue;}
        if(c=='/'){ tokens.push_back(CToken(DIV, "/")); continue;}
        if(c=='%'){ tokens.push_back(CToken(MOD, "%")); continue;}
        if(c=='('){ tokens.push_back(CToken(OPEN, "(")); continue;}
        if(c==')'){ tokens.push_back(CToken(CLOSE, ")")); continue;}
        if(c=='['){ tokens.push_back(CToken(BRA, "(")); continue;}
        if(c==']'){ tokens.push_back(CToken(KET, ")")); continue;}
        if(c==','){ tokens.push_back(CToken(COMMA, ",")); continue;}
        if(c=='?'){ tokens.push_back(CToken(QUEST, "?")); continue;}
        if(c==':'){ tokens.push_back(CToken(COLON, ":")); continue;}
        if(c=='!')
        {   if(i+1<s.length() && s[i+1]=='='){ tokens.push_back(CToken(NE, "!=")); i++;}
            else tokens.push_back(CToken(NOT, "!"));
            continue;
        }
        if(c=='<')
        {   if(i+1<s.length() && s[i+1]=='='){ tokens.push_back(CToken(LTE, "<=")); i++;}
            else tokens.push_back(CToken(LT, "<"));
            continue;
        }
        if(c=='>')
        {   if(i+1<s.length() && s[i+1]=='='){ tokens.push_back(CToken(GTE, ">=")); i++;}
            else tokens.push_back(CToken(GT, ">"));
            continue;
        }
        if(c=='=')
        {   i++;
            if(i==s.length()||s[i]!='=') Throw("syntax error: =");
            tokens.push_back(CToken(EQ, "==")); continue;
        }
        if(c=='&')
        {   i++;
            if(i==s.length()||s[i]!='&') Throw("syntax error: &");
            tokens.push_back(CToken(AND, "&&")); continue;
        }
        if(c=='|')
        {   i++;
            if(i==s.length()||s[i]!='|') Throw("syntax error: &");
            tokens.push_back(CToken(OR, "||")); continue;
        }
        if(c=='\'')
        {   unsigned j;
            for(j=i+1;j<s.length();j++) if(s[j]=='\'') break;
            if(j==s.length()) Throw("syntax error: unmatched  quote");
            tokens.push_back(CToken(REGEX, s.substr(i+1, j-i-1)));
            i=j; continue;
        }
        if(c=='_' || c=='.' || (c>='a' && c<='z') || (c>='A' && c<='Z') || (c>='0' && c<='9'))
        {   unsigned j;
            for(j=i+1;j<s.length();j++) if(s[j]!='_' && s[j]!='.' && !(s[j]>='a' && s[j]<='z') && !(s[j]>='A' && s[j]<='Z') && !(s[j]>='0' && s[j]<='9')) break;
            std::string t=s.substr(i, j-i);
            if(boost::regex_match(t, boost::regex("^\\.?[a-zA-Z_].*$"))) tokens.push_back(CToken(NAME, t));
            else if(boost::regex_match(t, boost::regex("^\\d*\\.?\\d+$|^\\d+\\.$"))) tokens.push_back(CToken(NUM, t.c_str(), atof(t.c_str())));
            else Throw(std::string("syntax error:: ")+t);
            i=j-1; continue;
        }
        Throw(std::string("syntax error: ")+c);
    }
}

CParser::CNode* CParser::Parse(std::string s)
{
    Tokenize(s);
    token_ptr=0;
    CNode* N;
    try
    {
        N=Parse8();
    }
    catch(CParser::CError& e)
    {   throw e;
    }
    catch(...)
    {   if(token_ptr>=tokens.size()) Throw("syntax error: end of line");
    }
    if(token_ptr<tokens.size()) Throw(tokens[token_ptr].type==REGEX ? std::string("syntax error: \'")+tokens[token_ptr].str+"\'" : std::string("syntax error: ")+tokens[token_ptr].str);
    return N;
}

CParser::CNode* CParser::Parse0()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N;
    if(tokens[token_ptr].type==NUM)
    {   N=new CConstNode(tokens[token_ptr].num);
        token_ptr++; return N;
    }
    if(tokens[token_ptr].type==NAME)
    {   std::string name=tokens[token_ptr].str;
        token_ptr++;
        if(token_ptr<tokens.size() && tokens[token_ptr].type==OPEN)
        {   token_ptr++;
            if(name!="D" && name!="DIFF" && name!="SUM" && name!="MIN" && name!="MAX" && name!="AVG" && name!="COUNT" && name!="BIN" && name!="CASE") Throw(std::string("undefined function: ")+name+"()");
            CNode* L=ParseList();
            if(!L) Throw(std::string("parameters list is empty: ")+name+"()");
            if(name=="D" || name=="DIFF")
            {   if(L->IsList()) N=new CDiffList(L);
                else
                {   CDiffNode* D=new CDiffNode(L);
                    N=D;
                }
            }
            else if(name=="SUM")
            {   if(L->IsList()) N=new CSumNode(L);
                else N=L;
            }
            else if(name=="MIN")
            {   if(L->IsList()) N=new CMinNode(L);
                else N=L;
            }
            else if(name=="MAX")
            {   if(L->IsList()) N=new CMaxNode(L);
                else N=L;
            }
            else if(name=="AVG")
            {   if(L->IsList()) N=new CAvgNode(L);
                else N=L;
            }
            else if(name=="COUNT")
            {   if(L->IsList()) N=new CCountNode(L);
                else
                {   N=new CConstNode(1);
                    delete L;
                }
            }
            else if(name=="BIN")
            {   if(L->IsList()) N=new CBinNode(L);
                else
                {   N=new CConstNode(0);
                    delete L;
                }
            }
            else if(name=="CASE")
            {   if(L->IsList()) N=new CCaseNode(L);
                else Throw("too few parameters: CASE(...)");
            }
            else Throw("???");
            if(token_ptr>=tokens.size() || tokens[token_ptr].type!=CLOSE)
            {   delete N; throw 0;
            }
            token_ptr++; return N;
        }
        else if(token_ptr<tokens.size() && tokens[token_ptr].type==BRA)
        {   token_ptr++;
            CNode* L=ParseList();
            if(!L) Throw(std::string("parameters list is empty: ")+name+"[]");
            if(all_vars.find(name)==all_vars.end()) all_vars[name]=new CVariable(current_file, current_line, name);
            N=new CMemList(all_vars[name], L);
            if(token_ptr>=tokens.size() || tokens[token_ptr].type!=KET)
            {   delete N; throw 0;
            }
            token_ptr++; return N;
        }
        else
        {   if(all_vars.find(name)==all_vars.end()) all_vars[name]=new CVariable(current_file, current_line, name);
            return new CVarNode(all_vars[name]);
        }
    }
    if(tokens[token_ptr].type==OPEN)
    {   token_ptr++;
        N=Parse8();
        if(token_ptr>=tokens.size() || tokens[token_ptr].type!=CLOSE)
        {   delete N; throw 0;
        }
        token_ptr++; return N;
    }
    throw 0;
}

CParser::CNode* CParser::Parse1()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N;
    if(tokens[token_ptr].type==MINUS)
    {   token_ptr++;
        CNode* N1=Parse0();
        N=new CUnaryNode(CUnaryNode::MINUS, N1);
        return N;
    }
    if(tokens[token_ptr].type==NOT)
    {   token_ptr++;
        CNode* N1=Parse0();
        N=new CUnaryNode(CUnaryNode::NOT, N1);
        return N;
    }
    return Parse0();
}

CParser::CNode* CParser::Parse2()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse1();
    while(token_ptr<tokens.size() && (tokens[token_ptr].type==MUL || tokens[token_ptr].type==DIV || tokens[token_ptr].type==MOD))
    {   CBinaryNode::TYPE op = tokens[token_ptr].type==MUL ? CBinaryNode::MUL : tokens[token_ptr].type==DIV ? CBinaryNode::DIV : CBinaryNode::MOD;
        token_ptr++;
        N2=Parse1();
        N1=new CBinaryNode(op, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse3()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse2();
    while(token_ptr<tokens.size() && (tokens[token_ptr].type==PLUS || tokens[token_ptr].type==MINUS))
    {   CBinaryNode::TYPE op = tokens[token_ptr].type==PLUS ? CBinaryNode::PLUS : CBinaryNode::MINUS;
        token_ptr++;
        N2=Parse2();
        N1=new CBinaryNode(op, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse4()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse3();
    if(token_ptr<tokens.size() && tokens[token_ptr].type==LT)
    {   token_ptr++;
        N2=Parse3();
        return new CBinaryNode(CBinaryNode::LT, N1, N2);
    }
    if(token_ptr<tokens.size() && tokens[token_ptr].type==GT)
    {   token_ptr++;
        N2=Parse3();
        return new CBinaryNode(CBinaryNode::GT, N1, N2);
    }
    if(token_ptr<tokens.size() && tokens[token_ptr].type==LTE)
    {   token_ptr++;
        N2=Parse3();
        return new CBinaryNode(CBinaryNode::LTE, N1, N2);
    }
    if(token_ptr<tokens.size() && tokens[token_ptr].type==GTE)
    {   token_ptr++;
        N2=Parse3();
        return new CBinaryNode(CBinaryNode::GTE, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse5()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse4();
    if(token_ptr<tokens.size() && tokens[token_ptr].type==EQ)
    {   token_ptr++;
        N2=Parse4();
        return new CBinaryNode(CBinaryNode::EQ, N1, N2);
    }
    if(token_ptr<tokens.size() && tokens[token_ptr].type==NE)
    {   token_ptr++;
        N2=Parse4();
        return new CBinaryNode(CBinaryNode::NE, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse6()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse5();
    while(token_ptr<tokens.size() && tokens[token_ptr].type==AND)
    {   token_ptr++;
        N2=Parse5();
        N1=new CBinaryNode(CBinaryNode::AND, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse7()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    N1=Parse6();
    while(token_ptr<tokens.size() && tokens[token_ptr].type==OR)
    {   token_ptr++;
        N2=Parse6();
        N1=new CBinaryNode(CBinaryNode::OR, N1, N2);
    }
    return N1;
}

CParser::CNode* CParser::Parse8()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N1;
    CNode* N2;
    CNode* N3;
    N1=Parse7();
    if(token_ptr<tokens.size() && tokens[token_ptr].type==QUEST)
    {   token_ptr++;
        N2=Parse8();
        if(token_ptr<tokens.size() && tokens[token_ptr].type==COLON)
        {   token_ptr++;
            N3=Parse8();
            N1=new CTernaryNode(N1, N2, N3);
        }
        else { delete N1; delete N2; throw 0;}
    }
    return N1;
}

CParser::CNode* CParser::Parse9()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N;
    if(tokens[token_ptr].type==REGEX)
    {   if(regexes.find(tokens[token_ptr].str)==regexes.end()) regexes[tokens[token_ptr].str]=new CRegEx(current_file, current_line, tokens[token_ptr].str);
        N=new CRegexNode(regexes[tokens[token_ptr].str]);
        token_ptr++;
    }
    else if(tokens[token_ptr].type==NAME && tokens[token_ptr].str=="D" && token_ptr+1<tokens.size() && tokens[token_ptr+1].type==REGEX)
    {   token_ptr++;
        if(regexes.find(tokens[token_ptr].str)==regexes.end()) regexes[tokens[token_ptr].str]=new CRegEx(current_file, current_line, tokens[token_ptr].str);
        N=new CRegexNode(regexes[tokens[token_ptr].str]);
        token_ptr++;
        N=new CDiffList(N);
    }
    else N=ParseRange();
    return N;
}

CParser::CNode* CParser::ParseRange()
{   if(token_ptr==tokens.size()) throw 0;
    CNode* N=Parse8();
    if(token_ptr<tokens.size() && tokens[token_ptr].type==COLON)
    {   token_ptr++;
        CNode*N1=Parse8();
        return new CRangeNode(N, N1);
    }
    return N;
}

CParser::CNode* CParser::ParseList()
{   std::vector<CParser::CNode*> V;
    ParseList(V);
    if(V.size()==0) return 0;
    if(V.size()==1) return V[0];
    return new CVector(V);
}

void CParser::ParseList(std::vector<CParser::CNode*>& V)
{   V.push_back(Parse9());
    while(token_ptr<tokens.size() && tokens[token_ptr].type==COMMA){ token_ptr++; V.push_back(Parse9());}
}

CParser::CNode* CParser::CNode::Scalar()
{   CNode* N=Flatten();
    if(N->IsList())
    {   delete N;
        throw std::string("vector in scalar context");
    }
    if(N->IsEmpty())
    {   delete N;
        throw std::string("empty list in scalar context");
    }
    return N;
}

CParser::CNode* CParser::CUnaryNode::Flatten()
{   CNode* M=N->Scalar();
    if(M!=N){ delete N; N=M;}
    if(N->IsConst()) return new CConstNode(Evaluate());
    return this;
}

double CParser::CUnaryNode::Evaluate()
{   switch(T)
    {   case CUnaryNode::MINUS: return -(N->Evaluate());
        case CUnaryNode::NOT:   return (double)!(N->Evaluate());
        default: throw 0;
    }
}

CParser::CNode* CParser::CBinaryNode::Flatten()
{   CNode* M=N1->Scalar();
    if(M!=N1){ delete N1; N1=M;}
    M=N2->Scalar();
    if(M!=N2){ delete N2; N2=M;}
    if(N1->IsConst() && N2->IsConst()) return new CConstNode(Evaluate());
    return this;
}

double CParser::CBinaryNode::Evaluate()
{   double x1=N1->Evaluate();
    double x2=N2->Evaluate();
    switch(T)
    {   case CBinaryNode::PLUS:  return x1 + x2;
        case CBinaryNode::MINUS: return x1 - x2;
        case CBinaryNode::MUL:   return x1 * x2;
        case CBinaryNode::DIV:   if(!x2) throw std::string("divide by zero"); return x1 / x2;
        case CBinaryNode::MOD:   return (double)((int64_t)x1 % (int64_t)x2);
        case CBinaryNode::LT:    return (double)(x1 < x2);
        case CBinaryNode::GT:    return (double)(x1 > x2);
        case CBinaryNode::LTE:   return (double)(x1 <= x2);
        case CBinaryNode::GTE:   return (double)(x1 >= x2);
        case CBinaryNode::EQ:    return (double)(x1 == x2);
        case CBinaryNode::NE:    return (double)(x1 != x2);
        case CBinaryNode::AND:   return (double)(x1 && x2);
        case CBinaryNode::OR:    return (double)(x1 || x2);
        default: throw 0;
    }
}

CParser::CNode* CParser::CTernaryNode::Flatten()
{   CNode* M=N1->Scalar();
    if(M!=N1){ delete N1; N1=M;}
    if(N1->IsConst())
    {   if(N1->Evaluate())
        {   M=N2->Scalar();
            if(M!=N2){ delete N2; N2=M;}
            M=N2; N2=0; return M;
        }
        else
        {   M=N3->Scalar();
            if(M!=N3){ delete N3; N3=M;}
            M=N3; N3=0; return M;
        }
    }
    M=N2->Scalar(); if(M!=N2){ delete N2; N2=M;}
    M=N3->Scalar(); if(M!=N3){ delete N3; N3=M;}
    return this;
}

double CParser::CTernaryNode::Evaluate()
{   return N1->Evaluate() ? N2->Evaluate() : N3->Evaluate();
}

CParser::CNode* CParser::CVarNode::Flatten()
{   if(V->bad) throw std::string("broken dependency: ")+V->name;
    if(V->reader && V->reader->IsConst()) return new CConstNode(V->reader->Value());
    if(!V->expr.empty() && V->expr[0]->IsConst()) return new CConstNode(V->expr[0]->Evaluate());
    return this;
}

double CParser::CVarNode::Evaluate()
{   if(T)
    {   if(V->history.size()<T) return 0;
        if(V->nahistory[T-1]) throw 0;
        return V->history[T-1];
    }
    if(V->na) throw 0;
    if(V->reader) return V->reader->Value();
    return V->value;
}

void CParser::CVariable::UpdateHistory()
{   if(!history.size()) for(unsigned i=0;i<size;i++)
    {   history.push_back(0.); nahistory.push_back(0);}
    for(int i=size-1;i;i--)
    {   history[i]=history[i-1];
        nahistory[i]=nahistory[i-1];
    }
    if(na) nahistory[0]=true;
    else
    {   history[0]=reader?reader->Value():value;
        nahistory[0]=false;
    }
}

CParser::CNode* CParser::CWalker::Flatten()
{   CNode* M=L->Flatten();
    if(M!=L){ delete L; L=M;}
    if(L->IsConst()) return new CConstNode(Evaluate());
    return this;
}

void CParser::CBinNode::Visit(CParser::CNode* n)
{   double d=n->Evaluate();
    if(first)
    {   x=d; value=0;
        empty=true;
        first=false;
    }
    else
    {   if(!empty && d<=last) throw 0;
        if(x>d) value++;
        empty=false;
        last=d;
    }
}

void CParser::CCaseNode::Visit(CParser::CNode* n)
{   if(!first && !empty) return;
    if(first)
    {   count=(int)n->Evaluate();
        if(count<0) throw 0;
        first=false;
    }
    else
    {   if(count){ count--; return;}
        value=n->Evaluate();
        empty=false;
    }
}

CParser::CNode* CParser::CVector::Flatten()
{   CNode* M;
    std::vector<CNode*> W;
    for(unsigned i=0;i<V.size();i++)
    {   M=V[i]->Flatten();
        if(M!=V[i]) delete V[i];
        if(M->IsList())
        {   CVector* X=dynamic_cast<CVector*>(M);
            for(unsigned k=0;k<X->V.size();k++) W.push_back(X->V[k]);
            X->V.clear();
            delete X;
        }
        else W.push_back(M);
    }
    M=this;
    if(W.size()==0) M=new CEmptyNode;
    if(W.size()==1){ M=W[0]; W.clear();}
    V.swap(W);
    return M;
}

CParser::CNode* CParser::CRegexNode::Flatten()
{   std::vector<CNode*> W;
    if(R->is_map)
    {   for(std::map<std::string, CReader*>::iterator J=R->map.begin();J!=R->map.end();J++)
        {   if(J->second->IsConst()) W.push_back(new CConstNode(J->second->Value()));
            else W.push_back(new CReaderNode(J->second));
        }
    }
    else
    {   for(unsigned i=0;i<R->vector.size();i++)
        {   if(R->vector[i]->IsConst()) W.push_back(new CConstNode(R->vector[i]->Value()));
            else W.push_back(new CReaderNode(R->vector[i]));
        }
    }
    if(W.size()==0) return new CEmptyNode;
    if(W.size()==1) return W[0];
    return new CVector(W);
}

CParser::CNode* CParser::CDiffNode::Flatten()
{   CNode* M=N->Scalar();
    if(M!=N){ delete N; N=M;}
    return this;
}

CParser::CNode* CParser::CDiffList::Flatten()
{   CNode* M=L->Flatten();
    if(M!=L){ delete L; L=M;}
    if(!L->IsList())
    {   if(L->IsEmpty()) M=L;
        else M=new CDiffNode(L);
        L=0; return M;
    }
    std::vector<CNode*> W;
    CVector* X=dynamic_cast<CVector*>(M);
    for(unsigned i=0;i<X->V.size();i++) W.push_back(new CDiffNode(X->V[i]));
    X->V.clear();
    if(W.size()==0) throw std::string("that cannot be 1");
    if(W.size()==1) throw std::string("that cannot be 2");
    return new CVector(W);
}

CParser::CNode* CParser::CMemList::Flatten()
{   CNode* M=L->Flatten();
    if(M!=L){ delete L; L=M;}
    if(L->IsEmpty()){ M=L; L=0; return M;}
    if(!L->IsList())
    {   if(!L->IsConst()) throw std::string("non-constant index");
        int t=(int)L->Evaluate();
        if(t<=0) throw std::string("index must be greater than zero");
        M=new CVarNode(V, (unsigned)t);
        L=0; return M;
    }
    std::vector<CNode*> W;
    CVector* X=dynamic_cast<CVector*>(M);
    for(unsigned i=0;i<X->V.size();i++)
    {   if(!X->V[i]->IsConst()) throw std::string("non-constant index");
        int t=(int)X->V[i]->Evaluate();
        if(t<=0) throw std::string("negative or zero index");
        W.push_back(new CVarNode(V, (unsigned)t));
    }
    X->V.clear();
    if(W.size()==0) throw std::string("that cannot be 3");
    if(W.size()==1) throw std::string("that cannot be 4");
    return new CVector(W);
}

CParser::CNode* CParser::CRangeNode::Flatten()
{   CNode* M=N1->Scalar();
    if(M!=N1){ delete N1; N1=M;}
    M=N2->Scalar();
    if(M!=N2){ delete N2; N2=M;}
    if(!N1->IsConst() || !N2->IsConst()) throw std::string("non-constant range");
    int a=(int) N1->Evaluate();
    int b=(int) N2->Evaluate();
    if(a==b) return new CConstNode(a);
    std::vector<CNode*> W;
    if(a<b) for(int n=a;n<=b;n++) W.push_back(new CConstNode(n));
    else for(int n=a;n>=b;n--) W.push_back(new CConstNode(n));
    return new CVector(W);
}

std::vector<CParser::CError> CParser::BindReader(CReaderManager* RM)
{   std::vector<CParser::CError> Err;
    for(std::map<std::string, CRegEx*>::iterator J=regexes.begin();J!=regexes.end();J++)
    {   if(J->second->is_map)
        {   J->second->map=RM->FindRegExAsMap(J->second->str);
            if(J->second->map.empty()) Err.push_back(CError(J->second->file, J->second->line, "", std::string("no matches found: '")+J->second->str+"'"));
        }
        else
        {   J->second->vector=RM->FindRegExAsVector(J->second->str);
            if(J->second->vector.empty()) Err.push_back(CError(J->second->file, J->second->line, "", std::string("no matches found: '")+J->second->str+"'"));
        }
    }
    for(unsigned i=0;i<p_t_regs.size();i++)
    {   std::map<std::string, CReader*> M=RM->FindRegExAsMap(p_t_regs[i]->rex);
        if(M.empty()) Err.push_back(CError(p_t_regs[i]->file, p_t_regs[i]->line, "", std::string("no matches found: '")+p_t_regs[i]->rex+"'"));
        for(std::map<std::string, CReader*>::iterator J=M.begin();J!=M.end();J++) p_t_regs[i]->names.push_back(J->first);
        std::sort(p_t_regs[i]->names.begin(), p_t_regs[i]->names.end());
        for(unsigned j=0;j<p_t_regs[i]->names.size();j++)
        {   p_t_regs[i]->readers.push_back(M[p_t_regs[i]->names[j]]);
            p_t_regs[i]->new_val.push_back(0);
            p_t_regs[i]->old_val.push_back(0);
            p_t_regs[i]->value.push_back(0);
        }
    }
    for(unsigned i=0;i<p_t_vars.size();i++)
    {   p_t_vars[i]->R=RM->FindReader(p_t_vars[i]->name);
        if(!p_t_vars[i]->R) Err.push_back(CError(p_t_vars[i]->file, p_t_vars[i]->line, "", std::string("no matches found: '")+p_t_vars[i]->name+"'"));
    }
    for(std::map<std::string, CVariable*>::iterator J=all_vars.begin();J!=all_vars.end();J++)
    {   CVariable* V=J->second;
        CReader* R=RM->FindReader(V->name);
        if(R)
        {   if(!V->formula.empty())
            {   if(R->IsDynamic()){ V->reader=R; dynamic.push_back(V);}
                if(!R->IsDynamic() && !R->IsDefault()) Err.push_back(CError(V->file, V->line, V->name, std::string("variable name conflict: ")+V->name));
            }
            else
            {   V->reader=R;
            }
        }
        else if(V->formula.empty())
        {   Err.push_back(CError(V->file, V->line, V->name, std::string("undefined variable: ")+V->name));
            V->bad=true; V->na=true;
        }
    }
    for(unsigned i=0;i<vars.size();i++)
    {   CVariable* V=vars[i];
        if(V->bad) continue;
        for(unsigned j=0;j<V->expr.size();j++)
        {   bool err=false;
            try
            {   CNode* N=V->expr[j]->Scalar();
                if(N!=V->expr[j])
                {   delete V->expr[j];
                    V->expr[j]=N;
                }
            }
            catch(std::string s)
            {   Err.push_back(CError(V->file, V->line, V->name, s));
                err=true;
            }
            catch(...)
            {   Err.push_back(CError(V->file, V->line, V->name, std::string("error")));
                err=true;
            }
            if(err)
            {   delete V->expr[j];
                for(unsigned k=j+1;k<V->expr.size();k++) V->expr[k-1]=V->expr[k];
                V->expr.pop_back();
                j--; continue;
            }
        }
        if(V->expr.empty() && !V->reader)
        {   V->bad=true; V->na=true;
        }
    }
    for(unsigned i=0;i<vars.size();i++)
    {   CVariable* V=vars[i];
        if(V->bad) continue;
        for(unsigned j=0;j<V->expr.size();j++) V->expr[j]->Recursion(CollectDiffs, this);
    }
    for(unsigned i=0;i<vars.size();i++) if(vars[i]->size) history.push_back(vars[i]);
    return Err;
}

void CParser::Execute()
{   for(unsigned i=0;i<vars.size();i++)
    {   CVariable* V=vars[i];
        if(V->bad) continue;
        V->na=true;
        for(unsigned j=0;j<V->expr.size();j++)
        {   try
            {   V->value=V->expr[j]->Evaluate();
                V->na=false;
                break;
            }
            catch(...){}
        }
    }
    for(unsigned i=0;i<p_t_regs.size();i++) p_t_regs[i]->Update();
    for(unsigned i=0;i<diffs.size();i++) diffs[i]->Record();
    for(unsigned i=0;i<history.size();i++) history[i]->UpdateHistory();
    for(unsigned i=0;i<dynamic.size();i++)
    {   CDynamicReader* Dr=dynamic_cast<CDynamicReader*>(dynamic[i]->reader);
        Dr->Set(dynamic[i]->value);
    }
}

bool CParser::Ready()
{   for(unsigned i=0;i<vars.size();i++)
    {   CVariable* V=vars[i];
        if(V->bad && V!=dot) continue;
        V->na=true;
        for(unsigned j=0;j<V->expr.size();j++)
        {   try
            {   V->value=V->expr[j]->Evaluate();
                V->na=false;
                break;
            }
            catch(...){}
        }
        if(V==dot) break;
    }
    return !dot->na && dot->value;
}

void CParser::CollectDiffs(CParser*P, CParser::CNode*N)
{   CDiffNode* D=dynamic_cast<CDiffNode*>(N);
    if(D) P->diffs.push_back(D);
}
