"""Standalone independent oracles; only Python stdlib, MoonBit and Node required."""
from pathlib import Path
import array,hashlib,itertools,json,math,os,random,subprocess,sys,tempfile,time,wave
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
def project(scene, output, expect=True):
    command = ['node',str(ROOT/'_build/js/debug/build/cmd/main/main.js'),'project',str(scene),str(output)]
    run = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',timeout=60)
    assert (run.returncode == 0) == expect, (run.stdout,run.stderr)
    result = json.loads(run.stdout)
    assert result['ok'] == expect
    return result

def wav_metrics(path, frames):
    with wave.open(str(path),'rb') as audio:
        assert (audio.getnchannels(),audio.getsampwidth(),audio.getframerate(),audio.getnframes())==(2,2,48000,frames)
        pcm = array.array('h', audio.readframes(frames))
    if sys.byteorder != 'little':
        pcm.byteswap()
    return max(abs(x) for x in pcm)/32767, math.sqrt(sum(x*x for x in pcm)/len(pcm))/32767

drama=ROOT/'examples/drama'
with tempfile.TemporaryDirectory(dir=WORK) as directory:
    folder=Path(directory)
    start=time.monotonic()
    result=project(drama/'scene.json',folder/'first')
    seconds=time.monotonic()-start
    assert result['frames']==744255 and result['sample_rate']==48000
    assert len(result['tracks'])==4 and result['tracks'][0]['source_frames']>240000
    observed={}
    for name in ('pan','binaural'):
        path=folder/'first'/(name+'.wav')
        peak,rms=wav_metrics(path,result['frames'])
        assert peak<=.981 and abs(peak-result[name]['output_peak'])<1/32767
        assert abs(rms-result['rms_target'])<1/32767
        observed[name]={'peak':peak,'rms':rms,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    assert observed['pan']['sha256']!=observed['binaural']['sha256']
    assert result['overload_review']['cues'] == []
    bad_scene = json.loads((drama/'scene-overload.json').read_text(encoding='utf-8'))
    repair_scene = json.loads((drama/'scene.json').read_text(encoding='utf-8'))
    changed = [track for track in bad_scene['tracks'] if track['name'] == 'approaching-steps']
    assert len(changed) == 1 and changed[0]['gain'] == 10.0
    changed[0]['gain'] = 1.6
    assert bad_scene == repair_scene
    overload = project(drama/'scene-overload.json',folder/'overload')
    assert overload['frames'] == result['frames']
    assert overload['binaural']['input_clipped_samples'] == 8
    assert result['binaural']['input_clipped_samples'] == 0
    assert overload['pan']['input_clipped_samples'] == 17
    assert result['pan']['input_clipped_samples'] == 0
    trace = overload['overload_review']
    assert trace['stage'] == 'binaural_before_attenuation'
    assert trace['merge_gap_frames'] == 960 and trace['omitted_cues'] == 0
    assert len(trace['cues']) == 2
    assert sum(cue['clipped_samples'] for cue in trace['cues']) == 8
    first = trace['cues'][0]
    assert (first['start_frame'], first['peak_frame'], first['end_frame_exclusive']) == (351601,351602,351628)
    assert first['peak_channel'] == 'left'
    assert [term['track'] for term in first['contributions']] == ['approaching-steps','narrator']
    for cue in trace['cues']:
        assert abs(sum(term['signed_sample'] for term in cue['contributions'])-cue['peak_sample']) < 1e-12
        assert cue['contributions'][0]['adds_to_peak']
        with wave.open(str(folder/'overload/binaural.wav'),'rb') as output:
            output.setpos(cue['peak_frame'])
            frame = output.readframes(1)
            ear = 0 if cue['peak_channel'] == 'left' else 2
            pcm_sample = int.from_bytes(frame[ear:ear+2],'little',signed=True)/32767
        assert abs(pcm_sample-cue['peak_sample']*overload['binaural']['gain_applied']) < 1/32767
    assert wav_metrics(folder/'overload/binaural.wav',overload['frames'])[0] <= .981
    overload_repair = {
        'track':'approaching-steps','original_gain':10.0,'repaired_gain':1.6,
        'raw_binaural_clipped_samples_before':overload['binaural']['input_clipped_samples'],
        'raw_binaural_clipped_samples_after':result['binaural']['input_clipped_samples'],
        'raw_binaural_peak_before':overload['binaural']['input_peak'],
        'raw_binaural_peak_after':result['binaural']['input_peak'],
        'overload_cues_before':len(trace['cues']),'overload_cues_after':len(result['overload_review']['cues']),
        'first_overload_cue':first,
    }
    project(drama/'scene.json',folder/'first',False)
    assert hashlib.sha256((folder/'first/binaural.wav').read_bytes()).hexdigest()==observed['binaural']['sha256']
    revision=project(drama/'scene-revised.json',folder/'revised')
    assert revision['frames']==result['frames']
    assert (folder/'first/binaural.wav').read_bytes()!=(folder/'revised/binaural.wav').read_bytes()
    fixed=json.loads((drama/'scene.json').read_text(encoding='utf-8'))
    fixed['hrir_file']=str(drama/'hrir.json')
    for track in fixed['tracks']:
        track['wav']=str(drama/track['wav'])
    fixed['tracks'][1]['keyframes'][1]['y']=-1
    fixed_path=folder/'fixed.json'
    fixed_path.write_text(json.dumps(fixed),encoding='utf-8')
    without_depth_motion=project(fixed_path,folder/'fixed')
    assert result['pan']['input_rms']==without_depth_motion['pan']['input_rms']
    assert abs(result['binaural']['input_rms']-without_depth_motion['binaural']['input_rms'])>1e-8
    bad=json.loads((drama/'scene.json').read_text(encoding='utf-8'))
    bad['hrir_file']=str(drama/'hrir.json')
    bad['tracks'][0]['wav']=str(folder/'truncated.wav')
    (folder/'truncated.wav').write_bytes((drama/'narrator.wav').read_bytes()[:45])
    invalid=folder/'invalid.json'
    invalid.write_text(json.dumps(bad),encoding='utf-8')
    project(invalid,folder/'bad',False)
    assert not (folder/'bad').exists()
report={'status':'passed','seed':20261031,'moving_measured_hrir_max_abs_error':error,
        'independent_multisource_superposition':True,'exclusive_output':True,
        'recorded_audio_frames':result['frames'],'sample_rate':48000,'tracks':4,
        'render_seconds':round(seconds,3),'pcm_observed':observed,
        'recorded_audio_overload_repair':overload_repair,
        'timeline_edit_changes_audio':True,'same_side_depth_motion_changes_binaural':True,
        'truncated_wav_rejected':True}

(WORK/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
