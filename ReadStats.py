import sys, re, gzip

forml=[]
input=[]
mac={}
vars={}
vlist=[]
eqn={}
unn={}
eqfn={}
eqln={}
wc={}
wcfn={}
wcln={}
data={}
bad={}
dbg=0
csv=0
outstd=""
outerr=""
badcmdline=0

for i in range(1, len(sys.argv)):
    if sys.argv[i]=="-d":
        dbg=1
    elif sys.argv[i]=="-csv":
        csv=1
    elif sys.argv[i]=="-o":
        i=i+1
        outstd=sys.argv[i]
    elif sys.argv[i]=="-e":
        i=i+1
        outerr=sys.argv[i]
    elif sys.argv[i][0]=="-":
        badcmdline=1
    elif re.search(r"\.stat$", sys.argv[i]) or re.search(r"\.stat.gz$", sys.argv[i]):
        input.append(sys.argv[i])
    else:
        forml.append(sys.argv[i])

if outstd:
    sys.stdout=open(outstd, "w")

if outerr:
    sys.stderr=open(outerr, "w")

if not input or not forml:
    sys.stderr.write("USAGE:\tReadStats.pl [options] <gsim.stat> <formula.txt> [<formula1.txt> [<formula2.txt> ...]] \noptions:\t-csv\t-- output in csv format\n")
    sys.exit(-1)

def read_formula(equation, file, lineno):
    st=''
    eq=''
    un=''
    m=re.match(r"^(\S+)\s*\((\S*)\)\s*=\s*(.*)\s*$", equation)
    if m:
        st=m.group(1)
        un=m.group(2)
        eq=m.group(3)
    else:
        m=re.match(r"^(\S+)\s*=\s*(.*)\s*$", equation)
        if m:
            st=m.group(1)
            eq=m.group(2)
    if not eq or not re.match(r"^@\w+@$|^\.?[a-zA-Z_][\w\.]*$", st):
        sys.stderr.write("##### "+file+" line "+str(lineno)+" - Incorrect syntax, line ignored:\t"+equation+"\n")
        return
    m=re.match(r"^([^@]*)@([^@]*)@(.*)$", eq)
    while m:
        if m.group(2) in mac:
            eq=m.group(1)+mac[m.group(2)]+m.group(3)
        else:
            sys.stderr.write("##### "+file+" line "+str(lineno)+" - Macro not defined, line ignored:\t@"+m.group(2)+"@\n")
            return
        m=re.match(r"^([^@]*)@([^@]*)@(.*)$", eq)
    m=re.match(r"^@([\w]+)@$", st)
    if m:
        mac[m.group(1)]=eq
    else:
        if st in vars:
            sys.stderr.write("##### "+file+" line "+str(lineno)+" - Duplicated stat, line ignored:\t"+st+"\n")
            return
        vars[st]={}
        vlist.append(st)
        eqn[st]=eq
        unn[st]=un
        eqfn[st]=file
        eqln[st]=lineno
        m=re.match(r"^([^']*)'([^']*)'(.*)$", eq)
        while m:
            qq="'"+m.group(2)+"'"
            wc[qq]=m.group(2)
            if qq not in wcfn.keys():
                wcfn[qq]=file
                wcln[qq]=lineno
            eq=m.group(1)+" "+m.group(3)
            m=re.match(r"^([^']*)'([^']*)'(.*)$", eq)
        m=re.match(r"^([^\w\.]*)([\w\.]+)(.*)$", eq)
        while m:
            eq=m.group(1)+m.group(3)
            vars[st][m.group(2)]=1
            m=re.match(r"^([^\w\.]*)([\w\.]+)(.*)$", eq)

def SUM(*a):
    sum=0
    for x in a:
        sum=sum+x
    return sum

###
### Read formula files
###
for formula in forml:
    lineno=0;
    linecount=0;
    equation='';
    fp=open(formula, "r")
    for line in fp:
        linecount=linecount+1
        comment=line.find('#')
        if comment!=-1:
            line=line[:comment]
        line=line.strip()
        if not line:
            continue
        if not equation:
            lineno=linecount
        tmp=line;
        m=re.match(r"^([^']*)('[^']*')(.*)$", tmp)
        while m:
            if m.group(2) not in wcfn.keys():
                wcfn[m.group(2)]=formula
                wcln[m.group(2)]=lineno
            tmp=m.group(3)
            m=re.match(r"^([^']*)('[^']*')(.*)$", tmp)
        equation=equation+line;
        if equation[-1]=='\\':
            equation=equation[:len(equation)-1]
            continue
        read_formula(equation, formula, lineno)
        equation=''
    fp.close()

###
### Check dependencies (topological sort + strongly connected components)
###
dep={}
for v in vars.keys():
    dep[v]={}
for v in vars.keys():
    for d in list(vars[v].keys()):
        if d in vars.keys():
            dep[d][v]=1
            if d==v:
                sys.stderr.write("##### "+eqfn[v]+" line "+str(eqln[v])+" - Circular dependency:\t"+v+" <- "+d+"\n")
                bad[d]=1;
        else:
            del vars[v][d]

dfs0={} # node visited
dfs1={} # node done
count=0
vvv=list(vars.keys())
for v in vvv:
    if v in dfs0.keys():
        continue
    dfs0[v]=1
    stack=[v]
    while stack:
        x=stack[-1]
        for d in list(dep[x].keys()):
            if d in dfs0.keys():
                del dep[x][d]
        if dep[x]:
            d=list(dep[x].keys())[0]
            dfs0[d]=1
            stack.append(d)
        else:
            count=count+1
            dfs1[x]=count
            stack.pop()

vvv=sorted(vvv, key=lambda z: -dfs1[z])

for v in vars.keys():
    for d in vars[v].keys():
        dep[v][d]=1
dfs0={}
for v in vvv:
    if v in dfs0.keys():
        continue
    dfs0[v]=1
    stack=[v]
    scc=[v]
    while stack:
        x=stack[-1]
        for d in list(dep[x].keys()):
            if d in dfs0.keys():
                del dep[x][d]
        if dep[x]:
            d=list(dep[x].keys())[0]
            dfs0[d]=1
            stack.append(d)
            scc.append(d)
        else:
            stack.pop()
    if len(scc)==1:
        continue
    msg="##### "+eqfn[v]+" line "+str(eqln[v])+" - Circular dependency:\t"
    for d in scc:
        bad[d]=1
        msg=msg+d+" <- "
    sys.stderr.write(msg+v+"\n")

###
### Read stat file
###
for fname in input:
    if fname[-3:]==".gz":
        fp=gzip.open(fname, "r")
    else:
        fp=open(fname, "r")
    for line in fp:
        if not isinstance(line, str):
            line=line.decode()
        comment=line.find('#')
        if comment!=-1:
            line=line[:comment]
        line=line.strip()
        m=re.match(r"^(\S+)\s+(\S+)$", line)
        if not m:
            continue
        st=m.group(1)
        val=m.group(2)
        data[st]=val
        for x in wc.keys():
            m=re.match(wc[x], st)
            if not m:
                continue
            if x in data:
                data[x]=data[x]+','+val
            else:
                data[x]=val
        if st in vars.keys():
            sys.stderr.write("##### "+eqfn[st]+" line "+str(eqln[st])+" - Name conflict:\t"+st+"\n")
            bad[st]=1;
    fp.close()

for x in sorted(wc.keys()):
    if x not in data.keys():
        sys.stderr.write("##### "+wcfn[x]+" line "+str(wcln[x])+" - No matches found:\t"+x+"\n")

###
### Evaluate
###
for st in vvv:
    if st in bad.keys():
        continue
    eqq=eqn[st].split("?=")
    for eq in eqq:
        tmp=eq
        expr=""
        m=re.match(r"^([^']*)('[^']*')(.*)$", tmp)
        while m:
            expr=expr+m.group(1)
            if m.group(2) in data.keys():
                expr=expr+data[m.group(2)]
            tmp=m.group(3)
            m=re.match(r"^([^']*)('[^']*')(.*)$", tmp)
        tmp=expr+tmp
        expr=""
        m=re.match(r"^(.*?)([\w\.]+)(.*)$", tmp)
        while m:
            expr=expr+m.group(1)
            if m.group(2) in data.keys():
                expr=expr+data[m.group(2)]
            else:
                expr=expr+m.group(2)
            tmp=m.group(3)
            m=re.match(r"^(.*?)([\w\.]+)(.*)$", tmp)
        expr=expr+tmp
        x=None
        try:
            x=eval(expr)
        except Exception:
            x=None
        if x is not None:
            data[st]=str(x)
            break
        elif dbg:
            sys.stderr.write("##### "+eqfn[st]+" line "+str(eqln[st])+" - Cannot evaluate:\t"+st+" = "+eq+"\n")
    if st not in data.keys():
        bad[st]=1
        if not dbg:
            sys.stderr.write("##### "+eqfn[st]+" line "+str(eqln[st])+" - Cannot evaluate:\t"+st+" = "+eq+"\n")

###
### Output
###
for st in vlist:
    if st[0]=='.' and not dbg:
        continue
    if st not in data.keys():
        continue
    val=data[st]
    if csv:
        print(st+","+val)
    else:
        print(st+"\t"+val)

