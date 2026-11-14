"""Promote reviewed original PCM into an upload-ready production checkpoint."""
from pathlib import Path
import hashlib,json,wave,sys
import numpy as np
import qa20261114_music as music
import qa20261114_media as media
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/"assets/audio/original-2026-11-14"
TIGHTENED="--tightened"in sys.argv
if TIGHTENED:OUT=OUT/"hatch-v3"
if not TIGHTENED and(OUT/"manifest.json").exists():
    raise RuntimeError("Prior seven uploaded masters are held/immutable. Use --tightened for the five new SFX only.")
if(OUT/"manifest.json").exists()and json.loads((OUT/"manifest.json").read_text()).get("uploaded"):
    raise RuntimeError("Uploaded master checkpoint is immutable; create a new revision folder for new geometry/timing.")
OUT.mkdir(exist_ok=True)
def read(path):
    with wave.open(str(path),'rb')as f:
        assert f.getframerate()==48000 and f.getsampwidth()==2 and f.getnchannels()==2
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,2).astype(np.float32)/32767
rows={}
for key,name in(()if TIGHTENED else(("garden","garden"),("deck","pocket-deck"))):
    path=OUT/(key+'-104bpm.wav');source=music.OUT/('little-afternoon-'+name+'-104bpm-full.wav')
    path.write_bytes(source.read_bytes());rows[key]={'file':path.name,'source':str(source.relative_to(ROOT)),'loop':True,'bpm':104,'bars':32}
for kind in('bear','toy','hue','material','feature'):
    cue_folder=media.OUT.parent/'revision-3-tightened'if TIGHTENED else media.OUT
    source=cue_folder/('bear-concept-cues.wav'if kind=='bear'else'toy-concept-cues.wav')
    signal=read(source)
    if kind in('hue','material'):
        audition=read(media.OUT/'item-material-accent-audition.wav')
        slot=1 if kind=='hue'else 3
        accent=audition[slot*48000:(slot+1)*48000]
        at=round((1.29 if TIGHTENED else 1.71)*48000);count=min(len(accent),len(signal)-at)
        signal[at:at+count]+=accent[:count]*.68
    path=OUT/('hatch-'+kind+('-v3-tightened'if TIGHTENED else'')+'-burst.wav');music.write(path,signal)
    meter=music.measure(path);short=media.shortterm(path)
    signal*=10**(min(-18-short,-3.2-meter['true_peak_dbfs'])/20)
    music.write(path,signal)
    rows['hatch_'+kind]={'file':path.name,'loop':False,'source':str(source.relative_to(ROOT)),'shortterm_lufs':media.shortterm(path),'music_baked_in':False,'clock':'play once at fresh native timeline age0; stop by receipt owner on skip/cancel/focus loss'}
for key,row in rows.items():
    path=OUT/row['file'];pcm=read(path)
    row.update(sha256=hashlib.sha256(path.read_bytes()).hexdigest(),samples=len(pcm),duration=len(pcm)/48000,sample_rate=48000,channels=2,expected_price=0,asset_id=None,**music.measure(path))
    assert row['true_peak_dbfs']<=-3 if not row['loop']else row['true_peak_dbfs']<=-1
(OUT/'manifest.json').write_text(json.dumps({'original':True,'source':'Astra original score / Sol additive synthesis; no samples/transcription','uploaded':False,'tightened_v3':TIGHTENED,'old_audio_ids_held':True,'assets':rows},indent=2),encoding='utf-8')
print(json.dumps({k:{x:r[x]for x in('file','duration','integrated_lufs','true_peak_dbfs')}for k,r in rows.items()},indent=2))
