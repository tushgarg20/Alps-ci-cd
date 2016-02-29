#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>
#include <boost/iostreams/filtering_stream.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#include "ExprParser.h"

/// Default reader -- return 0 if the stat not found

class CDefaultReader : public CParser::CReader
{   double value;
public:
    CDefaultReader(double d=0) : value(d) {}
    bool IsConst(){ return true;}
    bool IsDefault(){ return true;}
    double Value(){ return value;}
};

/// Dummy reader

class CDummyReaderManager : public CParser::CReaderManager
{
public:
    CParser::CReader* FindReader(std::string){ return 0;}
    std::vector<std::vector<std::string> > MatchPattern(std::string){ std::vector<std::vector<std::string> > V; return V;}
    std::vector<CParser::CReader*> FindRegExAsVector(std::string, std::map<std::string, double>* dumper=NULL){ std::vector<CParser::CReader*> V; return V;}
    std::map<std::string, CParser::CReader*> FindRegExAsMap(std::string, std::map<std::string, double>* dumper=NULL){ std::map<std::string, CParser::CReader*> M; return M;}
};

/// Timegraph reader

class CTimegraphReaderManager : public CParser::CReaderManager
{   std::ifstream file;
    boost::iostreams::filtering_istream ff;
    std::vector<std::string> names;
    std::vector<double> values;
    std::map<std::string, int> by_name;
    std::map<std::string, CParser::CReader*> readers;
    std::set<std::string> nnn;
    friend class CTimegraphReader;
public:
    CTimegraphReaderManager(const char*);
    ~CTimegraphReaderManager();
    CParser::CReader* FindReader(std::string);
    std::vector<std::vector<std::string> > MatchPattern(std::string);
    std::vector<CParser::CReader*> FindRegExAsVector(std::string, std::map<std::string, double>* dumper=NULL);
    std::map<std::string, CParser::CReader*> FindRegExAsMap(std::string, std::map<std::string, double>* dumper=NULL);
    bool ReadLine();
};

class CTimegraphReader : public CParser::CReader
{   int N;
    CTimegraphReaderManager* M;
public:
    CTimegraphReader(CTimegraphReaderManager*m, int n) : M(m), N(n) {}
    double Value(){ return M->values[N];}
};

CTimegraphReaderManager::~CTimegraphReaderManager()
{   for(std::map<std::string, CParser::CReader*>::iterator J=readers.begin();J!=readers.end();J++) delete J->second;
    file.close();
}

CTimegraphReaderManager::CTimegraphReaderManager(const char*fname)
{   file.open(fname, std::ios_base::in | std::ios_base::binary);
    if(!file.is_open()){ std::cerr << "Cannot open " << fname << "\n"; throw 0;}
    std::string S=fname;
    if(S.substr(S.length()-3)==".gz") ff.push(boost::iostreams::gzip_decompressor());
    ff.push(file);
    if(!getline(ff, S)){ std::cerr << "Cannot read " << fname << "\n"; throw 0;}
    int i, n;
    for(n=0;(i=S.find("\t", n))!=-1;n=i+1) names.push_back(S.substr(n, i-n));
    names.push_back(S.substr(n));
    for(uint32_t i=0;i<names.size();i++)
    {   if(names[i]!="") by_name[names[i]]=i;
        nnn.insert(names[i]);
        for(uint32_t i=1;i<names[i].length();i++) if(names[i][i]=='.') nnn.insert(names[i].substr(0, i));
    }
}

bool CTimegraphReaderManager::ReadLine()
{   std::string S;
    if(!getline(ff, S)) return false;
    int i, n;
    values.clear();
    for(n=0;(i=S.find("\t", n))!=-1;n=i+1) values.push_back(atof(S.substr(n, i-n).c_str()));
    values.push_back(atof(S.substr(n).c_str()));
    return true;
}

std::vector<std::vector<std::string> > CTimegraphReaderManager::MatchPattern(std::string s)
{   boost::regex rx(s);
    boost::smatch match;
    std::vector<std::vector<std::string> > V;
    for(std::set<std::string>::iterator J=nnn.begin();J!=nnn.end();J++)
    {   if(!boost::regex_match(*J, match, rx)) continue;
        std::vector<std::string> W;
        for(uint32_t k=1;k<match.size();k++) W.push_back(match[k]);
        bool found=false;
        for(uint32_t j=0;j<V.size();j++)
        {   if(V[j].size()!=W.size()) continue;
            uint32_t k;
            for(k=0;k<W.size();k++) if(W[k]!=V[j][k]) break;
            if(k<W.size()) continue;
            found=true; break;
        }
        if(!found) V.push_back(W);
    }
    return V;
}

CParser::CReader* CTimegraphReaderManager::FindReader(std::string name)
{   if(readers.find(name)!=readers.end()) return readers[name];
    if(by_name.find(name)!=by_name.end()) readers[name]=new CTimegraphReader(this, by_name[name]);
    else readers[name]=new CDefaultReader;
    return readers[name];
}

std::map<std::string, CParser::CReader*> CTimegraphReaderManager::FindRegExAsMap(std::string str, std::map<std::string, double>* dumper)
{   std::map<std::string, CParser::CReader*> M;
    boost::regex re(str);
    for(std::map<std::string, int>::iterator J=by_name.begin();J!=by_name.end();J++)
    {   if(!boost::regex_match(J->first, re)) continue;
        if(readers.find(str)==readers.end()) readers[J->first]=new CTimegraphReader(this, J->second);
        M[J->first]=readers[J->first];
    }
    return M;
}

std::vector<CParser::CReader*> CTimegraphReaderManager::FindRegExAsVector(std::string str, std::map<std::string, double>* dumper)
{   std::map<std::string, CParser::CReader*> M=FindRegExAsMap(str);
    std::vector<CParser::CReader*> V;
    for(std::map<std::string, CParser::CReader*>::iterator J=M.begin();J!=M.end();J++) V.push_back(J->second);
    return V;
}

/// Stat reader

class CStatReaderManager : public CParser::CReaderManager
{   std::map<std::string, double> values;
    std::map<std::string, CParser::CReader*> readers;
    std::set<std::string> nnn;
public:
    CStatReaderManager(const char*);
    ~CStatReaderManager(){ for(std::map<std::string, CParser::CReader*>::iterator J=readers.begin();J!=readers.end();J++) delete J->second;}
    CParser::CReader* FindReader(std::string);
    std::vector<std::vector<std::string> > MatchPattern(std::string);
    std::vector<CParser::CReader*> FindRegExAsVector(std::string, std::map<std::string, double>*);
    std::map<std::string, CParser::CReader*> FindRegExAsMap(std::string, std::map<std::string, double>*);
};

class CStatReader : public CParser::CReader
{   double value;
public:
    CStatReader(double d) : value(d) {}
    bool IsConst(){ return true;}
    double Value(){ return value;}
};

CStatReaderManager::CStatReaderManager(const char*fname)
{   std::ifstream file;
    boost::iostreams::filtering_istream ff;
    file.open(fname, std::ios_base::in | std::ios_base::binary);
    if(!file.is_open()){ std::cerr << "Cannot open " << fname << "\n"; throw 0;}
    std::string S=fname;
    if(S.substr(S.length()-3)==".gz") ff.push(boost::iostreams::gzip_decompressor());
    ff.push(file);
    while(getline(ff, S))
    {   int n=S.find('#');
        if(n!=-1) S=S.substr(0, n);
        S=CParser::Clip(S);
        if(S.empty()) continue;
        n=S.find_first_of(" \t");
        if(n==-1) continue;
        std::string left=CParser::Clip(S.substr(0, n));
        std::string right=CParser::Clip(S.substr(n));
        values[left]=atof(right.c_str());
        nnn.insert(left);
        for(uint32_t i=1;i<left.length();i++) if(left[i]=='.') nnn.insert(left.substr(0, i));
    }
}

std::vector<std::vector<std::string> > CStatReaderManager::MatchPattern(std::string s)
{   boost::regex rx(s);
    boost::smatch match;
    std::vector<std::vector<std::string> > V;
    for(std::set<std::string>::iterator J=nnn.begin();J!=nnn.end();J++)
    {   if(!boost::regex_match(*J, match, rx)) continue;
        std::vector<std::string> W;
        for(uint32_t k=1;k<match.size();k++) W.push_back(match[k]);
        bool found=false;
        for(uint32_t j=0;j<V.size();j++)
        {   if(V[j].size()!=W.size()) continue;
            uint32_t k;
            for(k=0;k<W.size();k++) if(W[k]!=V[j][k]) break;
            if(k<W.size()) continue;
            found=true; break;
        }
        if(!found) V.push_back(W);
    }
    return V;
}

CParser::CReader* CStatReaderManager::FindReader(std::string str)
{   if(readers.find(str)!=readers.end()) return readers[str];
    if(values.find(str)!=values.end()) readers[str]=new CStatReader(values[str]);
    else readers[str]=new CDefaultReader;
    return readers[str];
}

std::map<std::string, CParser::CReader*> CStatReaderManager::FindRegExAsMap(std::string str, std::map<std::string, double>* dumper)
{   std::map<std::string, CParser::CReader*> M;
    boost::regex re(str);
    for(std::map<std::string, double>::iterator J=values.begin();J!=values.end();J++)
    {   if(!boost::regex_match(J->first, re)) continue;
        if(readers.find(str)==readers.end()) readers[J->first]=new CStatReader(J->second);
        M[J->first]=readers[J->first];
        (*dumper)[J->first] = J->second;
    }
    return M;
}

std::vector<CParser::CReader*> CStatReaderManager::FindRegExAsVector(std::string str, std::map<std::string, double>* dumper)
{   std::map<std::string, CParser::CReader*> M=FindRegExAsMap(str, dumper);
    std::vector<CParser::CReader*> V;
    for(std::map<std::string, CParser::CReader*>::iterator J=M.begin();J!=M.end();J++) V.push_back(J->second);
    return V;
}

/// main

char* Usage=
"Command line options:\n"
"\t-i <formula.txt>\t- formula file; can be multiple\n"
"\t-f <formula-list.txt>\t- formula files list; can be multiple\n"
"\t-s <stat-file>\t- parse a stat file\n"
"\t-t <timegraph>\t- parse a timegraph file\n"
"\t-o <output>\t- output stream (default: stdout)\n"
"\t-os <output>\t- output stream containing stats (default: file name)\n"
"\t-dv\t- output stream with stats will have values instead of 0\n"
"\t-e <error-log>\t- error stream (default: stderr)\n"
"\t-d\t- debug output\n"
"\t-csv\t- output in .csv format (default: tab-delimited)\n"
"at least one -i or -f is required\n"
"options -s and -t are mutually exclusive\n"
"if none specified, just checking the formula syntax\n"
"multiple -o -e -s -t are not allowed\n"
;

void print_error(CParser::CError& e)
{   std::cerr<<"### "<<e.file<<" line "<<e.line;
    if(!e.var.empty()) std::cerr<<" "<<e.var;
    std::cerr<<" - "<<e.message<<std::endl;
}

int main(int argc, char** argv)
{   bool csv=false;
    bool dbg=false;
    bool dumpstats=false;
    bool dumpstatsval=false;
    std::string statfile;
    std::string timegraph;
    std::string outfile;
    std::string errfile;
    std::string outstatfile;
    std::vector<std::string> iii;
    std::vector<std::string> fff;
    std::vector<std::string> input;
    try
    {   for(int i=1;i<argc;i++)
        {   if(std::string("-csv")==argv[i]){ csv=true; continue;}
            if(std::string("-d")==argv[i]){ dbg=true; continue;}
            if(std::string("-dv")==argv[i]){ dumpstatsval=true; continue;}
            if(std::string("-t")==argv[i])
            {   if(!timegraph.empty()) throw 0;
                i++; if(i>=argc) throw 0;
                timegraph=argv[i]; continue;
            }
            if(std::string("-s")==argv[i])
            {   if(!statfile.empty()) throw 0;
                i++; if(i>=argc) throw 0;
                statfile=argv[i]; continue;
            }
            if(std::string("-o")==argv[i])
            {   if(!outfile.empty()) throw 0;
                i++; if(i>=argc) throw 0;
                outfile=argv[i]; continue;
            }
            if(std::string("-os")==argv[i])
            {   if(!outstatfile.empty()) throw 0;
                i++; if(i>=argc) throw 0;
                dumpstats=true;
                outstatfile=argv[i]; continue;
            }
            if(std::string("-e")==argv[i])
            {   if(!errfile.empty()) throw 0;
                i++; if(i>=argc) throw 0;
                errfile=argv[i]; continue;
            }
            if(std::string("-i")==argv[i])
            {   i++; if(i>=argc) throw 0;
                iii.push_back(argv[i]);
                fff.push_back(""); continue;
            }
            if(std::string("-f")==argv[i])
            {   i++; if(i>=argc) throw 0;
                fff.push_back(argv[i]);
                iii.push_back(""); continue;
            }
            throw 0;
        }
        if(!iii.size()) throw 0;
    }
    catch(...){ std::cerr<<Usage; return 0;}

    std::ofstream err;
    std::ofstream out;
    std::ofstream outstat;
    std::string S;

    if(!errfile.empty())
    {   err.open(errfile.c_str());
        if(err.is_open()) std::cerr.rdbuf(err.rdbuf());
        else std::cerr<<"Cannot open "<<errfile<<"\n";
    }
    if(!outfile.empty())
    {   out.open(outfile.c_str());
        if(out.is_open()) std::cout.rdbuf(out.rdbuf()); // STYLE_IGNORE_COUT
        else std::cerr<<"Cannot open "<<outfile<<"\n";
    }
    if(!outstatfile.empty())
    {   outstat.open(outstatfile.c_str());
        if(!outstat.is_open()) {std::cerr<<"Cannot open "<<outstatfile<<"\n"; dumpstats=false;}
    }
    for(uint32_t i=0;i<iii.size();i++)
    {   if(!iii[i].empty()) input.push_back(iii[i]);
        else
        {   std::ifstream file(fff[i].c_str());
            if(!file.is_open()){ std::cerr << "Cannot open "<<fff[i]<<"\n"; return 0;}
            while(getline(file, S))
            {   int n=S.find('#');
                if(n!=-1) S=S.substr(0, n);
                S=CParser::Clip(S);
                if(!S.empty()) input.push_back(S);
            }
        }
    }

    CParser P;
    std::map<std::string, std::vector<CParser::CError> > EEE;
    std::map<std::string, std::string> comm;

    for(uint32_t i=0;i<input.size();i++)
    {   std::ifstream file;
        file.open(input[i].c_str());
        if(!file.is_open()){ std::cerr<<"Cannot open "<<input[i]<<"\n"; return 0;}
        std::vector<CParser::CError> E;
        P.Start(input[i].c_str());
        while(getline(file, S))
        {   int n=S.find('#');
            if(n!=-1)
            {   std::string comment=S.substr(n);
                S=S.substr(0, n);
                int m=S.find('=');
                if(m!=-1) comm[CParser::Clip(S.substr(0, m))]=comment;
            }
            try{ P.ReadLine(S.c_str());}
            catch(CParser::CError& e){ E.push_back(e);}
        }
        try{ P.Finish();}
        catch(CParser::CError& e){ E.push_back(e);}
        file.close();
        EEE[input[i]]=E;
    }

    std::cout.precision(20); // STYLE_IGNORE_COUT
    
    if(!statfile.empty())
    {   CStatReaderManager STM(statfile.c_str());
        std::vector<CParser::CError> Err=P.Initialize(&STM);
        std::map<std::string, double> Statdump;
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        Err=P.CheckDependencies();
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        Err=P.BindReader(&STM, &Statdump);
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        for(uint32_t i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(uint32_t i=0;i<E.size();i++) print_error(E[i]);
        }

        if(dumpstats)
        {
            for(std::map<std::string, double>::iterator J=Statdump.begin();J!=Statdump.end();J++)
            {
                if(dumpstatsval) {
                    outstat<<","<<J->first<<","<<J->second<<",,!,,ALPs"<<std::endl;
                } else {
                    if(J->second) outstat<<","<<J->first<<",0,,!,,ALPs"<<std::endl;
                }
            }
            outstat.close();
        }

        P.Execute();
        for(size_t i=0;i<P.Size();i++)
        {   const CParser::CReport* R=P.Report(i);
            for(size_t j=0;j<R->Size();j++)
            {   if(!dbg && R->Name(j)[0]=='.') continue;
                std::cout<<R->Name(j)<<(csv?",":"\t");                              // STYLE_IGNORE_COUT
                if(R->Bad(j)) std::cout<<"n/a";                                     // STYLE_IGNORE_COUT
                else std::cout<<R->Value(j);                                        // STYLE_IGNORE_COUT
                std::cout<<(csv?",":"\t");                                          // STYLE_IGNORE_COUT
                if(comm.find(R->Name(j))!=comm.end()) std::cout<<comm[R->Name(j)];  // STYLE_IGNORE_COUT
                std::cout<<"\n";                                                    // STYLE_IGNORE_COUT
            }
        }
    }
    else if(!timegraph.empty())
    {   CTimegraphReaderManager TGM(timegraph.c_str());
        std::vector<CParser::CError> Err=P.Initialize(&TGM);
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        Err=P.CheckDependencies();
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        Err=P.BindReader(&TGM);
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        for(uint32_t i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(uint32_t i=0;i<E.size();i++) print_error(E[i]);
        }
        
        bool separate=false;
        for(size_t i=0;i<P.Size();i++)
        {   const CParser::CReport* R=P.Report(i);
            for(size_t j=0;j<R->Size();j++)
            {   if(dbg && R->Name(j)[0]=='.') continue;
                std::cout<<(separate?(csv?",":"\t"):"")<<R->Name(j); // STYLE_IGNORE_COUT
                separate=true;
            }
        }
        std::cout<<"\n"; // STYLE_IGNORE_COUT

        while(TGM.ReadLine())
        {   P.Execute();
            separate=false;
            for(size_t i=0;i<P.Size();i++)
            {   const CParser::CReport* R=P.Report(i);
                for(size_t j=0;j<R->Size();j++)
                {   if(dbg && R->Name(j)[0]=='.') continue;
                    std::cout<<(separate?(csv?",":"\t"):"");    // STYLE_IGNORE_COUT
                    if(R->Bad(j)) std::cout<<"n/a";             // STYLE_IGNORE_COUT
                    else std::cout<<R->Value(j);                // STYLE_IGNORE_COUT
                    separate=true;
                }
            }
            std::cout<<"\n";                                    // STYLE_IGNORE_COUT
        }
    }
    else
    {   CDummyReaderManager DMM;
        std::vector<CParser::CError> Err=P.Initialize(&DMM);
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        Err=P.CheckDependencies();
        for(uint32_t i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);

        for(uint32_t i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(uint32_t i=0;i<E.size();i++) print_error(E[i]);
        }
    }
}
