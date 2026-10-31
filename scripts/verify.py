"""Standalone independent oracles; only Python stdlib, MoonBit and Node required."""
from pathlib import Path
import itertools,json,math,os,random,subprocess,wave
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'_build/oracle';WORK.mkdir(parents=True,exist_ok=True)
R=random.Random(20261031)
MOON=os.environ.get('MOON_BIN','moon')
def invoke(args):
    p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    assert p.returncode==0,(args,p.stdout,p.stderr)
    return p.stdout
invoke([MOON,'build','--target','js','--deny-warn'])
def request(data,ok=True):
    path=WORK/'request.json';path.write_text(json.dumps(data),encoding='utf-8')
    p=subprocess.run(['node',str(ROOT/'_build/js/debug/build/cmd/main/main.js'),str(path)],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    result=json.loads(p.stdout)
    assert result['ok']==ok and (p.returncode==0)==ok,(p.stdout,p.stderr)
    return result

def hrir(name):
    with wave.open(str(ROOT/'testdata/raw-symmetric-cube-hrirs'/name),'rb') as w:
        width=w.getsampwidth();data=w.readframes(w.getnframes());assert w.getnchannels()==2
        values=[int.from_bytes(data[i:i+width],'little',signed=True)/2**(width*8-1) for i in range(0,len(data),width)]
    return values[::2],values[1::2]
h=[hrir('E35_A45.wav'),hrir('E35_A-45.wav')]
dirs=[dict(x=1,y=1,z=1),dict(x=1,y=-1,z=1)]
measurements=[dict(direction=d,left=ear[0],right=ear[1]) for d,ear in zip(dirs,h)]
x=[R.uniform(-.5,.5) for _ in range(1200)]
frames=[dict(at=0,direction=dirs[0]),dict(at=400,direction=dirs[1]),dict(at=800,direction=dirs[0])]
base=dict(measurements=measurements,sample_rate=48000,hrir_rate=48000,fade_samples=64)
result=request(dict(base,input=x,keyframes=frames))
def conv(x,filter):
    return [sum(x[j]*filter[t-j] for j in range(max(0,t-len(filter)+1),min(t+1,len(x)))) for t in range(len(x)+len(filter)-1)]
error=0
for ei,ear in enumerate(['left','right']):
    a,b=conv(x,h[0][ei]),conv(x,h[1][ei]);reference=[]
    for t in range(len(a)):
        alpha=(t-400+1)/64 if 400<=t<464 else (t-800+1)/64 if 800<=t<864 else None
        reference.append((1-alpha)*a[t]+alpha*b[t] if 400<=t<464 else
                         (1-alpha)*b[t]+alpha*a[t] if 800<=t<864 else b[t] if 464<=t<800 else a[t])
    error=max(error,max(abs(a-b) for a,b in zip(result[ear],reference)))
assert error<1e-11
# Independent linear superposition for sources with different start offsets.
short=x[:160];sources=[dict(samples=short,keyframes=[frames[0]],start=0,gain=.5),
                       dict(samples=short,keyframes=[dict(at=0,direction=dirs[1])],start=37,gain=-.25)]
mixed=request(dict(base,sources=sources))
for ei,ear in enumerate(['left','right']):
    a,b=conv(short,h[0][ei]),conv(short,h[1][ei]);ref=[0.]*(len(b)+37)
    for i,v in enumerate(a):ref[i]+=.5*v
    for i,v in enumerate(b):ref[i+37]-=.25*v
    assert len(mixed[ear])==len(ref)
    assert max(abs(a-b) for a,b in zip(mixed[ear],ref))<1e-11
out=WORK/'exclusive.wav'
if out.exists():out.unlink()
file_req=dict(base,sources=sources,output=str(out))
request(file_req);old=out.read_bytes();request(file_req,False);assert old==out.read_bytes()
with wave.open(str(out),'rb') as w:assert w.getnchannels()==2 and w.getframerate()==48000
request(dict(base,input=x,keyframes=frames,hrir_rate=44100),False)
report={'status':'passed','seed':20261031,'moving_measured_hrir_max_abs_error':error,'independent_multisource_superposition':True,'exclusive_output':True}

(WORK/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
