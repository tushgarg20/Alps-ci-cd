#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>
#include <boost/iostreams/filtering_stream.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#include "ExprParser.h"

/// Timegraph reader

class CTimegraphReaderManager : public CParser::CReaderManager
{   std::ifstream file;
    boost::iostreams::filtering_istream ff;
    std::vector<std::string> names;
    std::vector<double> values;
    std::map<std::string, int> by_name;
    std::map<std::string, CParser::CReader*> readers;
    friend class CTimegraphReader;
public:
    CTimegraphReaderManager(const char*);
    ~CTimegraphReaderManager();
    CParser::CReader* FindReader(std::string);
    std::map<std::string, CParser::CReader*> FindRegEx(std::string);
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
{   file.close();
    for(std::map<std::string, CParser::CReader*>::iterator J=readers.begin();J!=readers.end();J++) delete J->second;
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
    for(unsigned i=0;i<names.size();i++) if(names[i]!="") by_name[names[i]]=i;
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

CParser::CReader* CTimegraphReaderManager::FindReader(std::string name)
{   if(by_name.find(name)==by_name.end()) return 0;
    if(readers.find(name)==readers.end()) readers[name]=new CTimegraphReader(this, by_name[name]);
    return readers[name];
}

std::map<std::string, CParser::CReader*> CTimegraphReaderManager::FindRegEx(std::string str)
{   std::map<std::string, CParser::CReader*> M;
    boost::regex re(str);
    for(std::map<std::string, int>::iterator J=by_name.begin();J!=by_name.end();J++)
    {   if(!boost::regex_match(J->first, re)) continue;
        M[J->first]=FindReader(J->first);
    }
    return M;
}

/// Stat reader

class CStatReaderManager : public CParser::CReaderManager
{   std::map<std::string, double> values;
    std::vector<CParser::CReader*> readers;
public:
    CStatReaderManager(const char*);
    ~CStatReaderManager(){ for(unsigned i=0;i<readers.size();i++) delete readers[i];}
    CParser::CReader* FindReader(std::string);
    std::map<std::string, CParser::CReader*> FindRegEx(std::string);
};

class CStatReader : public CParser::CReader
{   double value;
public:
    CStatReader(double d) : value(d) {}
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
    }
}

CParser::CReader* CStatReaderManager::FindReader(std::string str)
{   return values.find(str)==values.end() ? 0 : new CStatReader(values[str]);
}

std::map<std::string, CParser::CReader*> CStatReaderManager::FindRegEx(std::string str)
{   std::map<std::string, CParser::CReader*> M;
    boost::regex re(str);
    for(std::map<std::string, double>::iterator J=values.begin();J!=values.end();J++)
    {   if(!boost::regex_match(J->first, re)) continue;
        M[J->first]=new CStatReader(J->second);
    }
    return M;
}

/// main

char* Usage=
"Command line options:\n"
"\t-i <formula.txt>\t- formula file; can be multiple\n"
"\t-f <formula-list.txt>\t- formula files list; can be multiple\n"
"\t-s <stat-file>\t- parse a stat file\n"
"\t-t <timegraph>\t- parse a timegraph file\n"
"\t-o <output>\t- output stream (default: stdout)\n"
"\t-e <error-log>\t- error stream (default: stderr)\n"
"\t-d\t- debug output\n"
"\t-csv\t- output in .csv format (default: tab-delimited)\n"
"at least one -i or -f is required\n"
"options -s and -t are mutually exclusive\n"
"if none specified, just checking the formula syntax\n"
"multiple -o -e -s -t are not allowed\n"
;

int main(int argc, char** argv)
{   bool csv=false;
    bool dbg=false;
    std::string statfile;
    std::string timegraph;
    std::string outfile;
    std::string errfile;
    std::vector<std::string> iii;
    std::vector<std::string> fff;
    std::vector<std::string> input;
    try
    {   for(int i=1;i<argc;i++)
        {   if(std::string("-csv")==argv[i]){ csv=true; continue;}
            if(std::string("-d")==argv[i]){ dbg=true; continue;}
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
    std::string S;

    if(!errfile.empty())
    {   err.open(errfile.c_str());
        if(err.is_open()) std::cerr.rdbuf(err.rdbuf());
        else std::cerr<<"Cannot open "<<errfile<<"\n";
    }
    if(!outfile.empty())
    {   out.open(outfile.c_str());
        if(out.is_open()) std::cout.rdbuf(out.rdbuf());
        else std::cerr<<"Cannot open "<<outfile<<"\n";
    }
    for(unsigned i=0;i<iii.size();i++)
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

    for(unsigned i=0;i<input.size();i++)
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

    std::vector<CParser::CError> Err=P.CheckDependencies();
    for(unsigned i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);

    std::cout.precision(20);
    
    if(!statfile.empty())
    {   CStatReaderManager STM(statfile.c_str());
        Err=P.BindReader(&STM);
        for(unsigned i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        for(unsigned i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(unsigned i=0;i<E.size();i++) std::cerr<<"### "<<E[i].file<<" line "<<E[i].line<<" - "<<E[i].message<<std::endl;
        }

        P.Execute();
        for(int i=0;i<P.Size();i++)
        {   if(!dbg && P.Name(i)[0]=='.') continue;
            std::cout<<P.Name(i)<<(csv?",":"\t");
            if(P.Bad(i)) std::cout<<"n/a";
            else std::cout<<P.Value(i);
            std::cout<<(csv?",":"\t");
            if(comm.find(P.Name(i))!=comm.end()) std::cout<<comm[P.Name(i)];
            std::cout<<"\n";
        }
    }
    else if(!timegraph.empty())
    {   CTimegraphReaderManager TGM(timegraph.c_str());
        Err=P.BindReader(&TGM);
        for(unsigned i=0;i<Err.size();i++) EEE[Err[i].file].push_back(Err[i]);
        for(unsigned i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(unsigned i=0;i<E.size();i++) std::cerr<<"### "<<E[i].file<<" line "<<E[i].line<<" - "<<E[i].message<<std::endl;
        }
        
        bool separate=false;
        for(int i=0;i<P.Size();i++)
        {   if(dbg && P.Name(i)[0]=='.') continue;
            std::cout<<(separate?(csv?",":"\t"):"")<<P.Name(i);
            separate=true;
        }
        std::cout<<"\n";

        while(TGM.ReadLine())
        {   P.Execute();
            separate=false;    
            for(int i=0;i<P.Size();i++)
            {   if(dbg && P.Name(i)[0]=='.') continue;
                std::cout<<(separate?(csv?",":"\t"):"");
                if(P.Bad(i)) std::cout<<"n/a";
                else std::cout<<P.Value(i);
                separate=true;
            }
            std::cout<<"\n";
        }
    }
    else
    {   for(unsigned i=0;i<input.size();i++)
        {   std::vector<CParser::CError>& E=EEE[input[i]];
            std::stable_sort(E.begin(), E.end(), CParser::CError::Cmp);
            for(unsigned i=0;i<E.size();i++) std::cerr<<"### "<<E[i].file<<" line "<<E[i].line<<" - "<<E[i].message<<std::endl;
        }
    }
}

