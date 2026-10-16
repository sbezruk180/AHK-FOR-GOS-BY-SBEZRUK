import re

def functions(text):
    found=[]
    for m in re.finditer(r'(?m)^([A-Za-z_]\w*)\([^\n]*\)(?: *\{|[ \t]*\n\{)',text):
        start=m.start(); i=m.end()-1; depth=0; quoted=False; block_comment=False
        while i < len(text):
            ch=text[i]
            if block_comment:
                if text.startswith('*/',i):block_comment=False;i+=2;continue
                i+=1;continue
            if not quoted and (i==0 or text[i-1]=='\n'):
                lineend=text.find('\n',i)
                if lineend<0:lineend=len(text)
                line=text[i:lineend].lstrip()
                if line.startswith('/*'):block_comment=True;i+=2;continue
                if re.match(r'^\((?:\s|$|LTrim|RTrim|Join|Comments|`|%)',line,re.I):
                    close=re.search(r'(?m)^\s*\)[^\n]*',text[lineend:])
                    if not close:raise ValueError(m.group(1)+' unclosed continuation')
                    i=lineend+close.end();continue
            if ch=='`':i+=2;continue
            if ch=='"':
                if quoted and text[i:i+2]=='""':i+=2;continue
                quoted=not quoted;i+=1;continue
            if not quoted:
                if ch==';' and (i==0 or text[i-1].isspace()):
                    i=text.find('\n',i)
                    if i<0:break
                    continue
                if ch=='{':depth+=1
                if ch=='}':
                    depth-=1
                    if depth==0:
                        found.append((m.group(1),start,i+1,text[start:i+1]));break
            i+=1
        else:raise ValueError(m.group(1)+' unclosed function')
    for a,b in zip(found,found[1:]):
        if a[2]>b[1]:raise ValueError('overlap '+a[0]+' '+b[0])
    return found
