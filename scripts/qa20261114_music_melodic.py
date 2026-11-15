"""New v4 local garden audition. Never edits v3, source recordings or runtime audio."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/audio/sample-sources/opengameart-2026-11-14"
OUT = ROOT / "artifacts/qa-2026-11-14-v634/audio/revision-4-melodic"
SR, BEAT, FRAMES, SEED = 48000, 40000, 1280000, 2026111404
ATTACK, RELEASE = .045, .140
NOTES = {"F4":349.228231433, "G4":391.995435982, "A4":440., "C5":523.251130601, "D5":587.329535835}
BARS = [
 [( .5,"A4",.75),(1.5,"C5",.5),(2.25,"D5",1.25)],
 [(0,"C5",.75),(1,"A4",1),(2.5,"G4",.5),(3.25,"A4",.5)],
 [(.5,"F4",.75),(1.5,"A4",.5),(2.25,"C5",1.25)],
 [(0,"D5",.75),(1,"C5",1),(2.5,"A4",.5),(3.25,"G4",.5)],
 [(.5,"A4",.75),(1.5,"C5",.5),(2.25,"D5",1.25)],
 [(0,"C5",.75),(1,"A4",1),(2.5,"G4",.5),(3.25,"A4",.5)],
 [(.5,"A4",.75),(1.5,"G4",.5),(2.25,"F4",1.25)],
 [(0,"G4",.75),(1,"A4",.75),(2.25,"F4",1.25)]]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def decode(path):
    result = subprocess.run(["ffmpeg","-v","error","-i",str(path),"-ac","1","-ar",str(SR),"-f","f32le","pipe:1"],capture_output=True,check=True)
    return np.frombuffer(result.stdout,"<f4").astype(np.float64)


def pcm(path,signal):
    assert np.isfinite(signal).all() and np.max(np.abs(signal)) < .95
    values = np.rint(signal*32767).astype("<i2")
    with wave.open(str(path),"wb") as output:
        output.setnchannels(1 if signal.ndim==1 else signal.shape[1]);output.setsampwidth(2);output.setframerate(SR);output.writeframes(values.tobytes())
    return values.astype(np.float64)/32767


def read_pcm(path):
    with wave.open(str(path),"rb") as source:
        values=np.frombuffer(source.readframes(source.getnframes()),"<i2").astype(np.float64)/32767
        return values if source.getnchannels()==1 else values.reshape(-1,source.getnchannels())


def rms(value): return float(np.sqrt(np.mean(value*value)))


def db(value): return 20*math.log10(max(1e-20,float(value)))


def preserved():
    paths = list(SOURCE.rglob("*")) + [ROOT/"scripts/qa20261114_music_sparse.py"]
    for folder in ("revision-3-sparse","revision-3-full"):
        paths += list((OUT.parent/folder).rglob("*"))
    return {str(p.relative_to(ROOT)):sha(p) for p in paths if p.is_file()}


def sources():
    provenance=json.loads((SOURCE/"provenance.json").read_text(encoding="utf-8"))
    for row in provenance["sources"]:
        page=SOURCE/row["license_page_file"]
        assert sha(page)==row["license_page_sha256"] and "creativecommons.org/publicdomain/zero/1.0/" in page.read_text(encoding="utf-8")
        for item in row["files"]:
            path=(SOURCE/item["source_filename"]).resolve();assert path.is_relative_to(SOURCE.resolve()) and sha(path)==item["sha256"]
            for wav in item.get("extracted_wavs",[]):
                path=(SOURCE/wav["local_file"]).resolve();assert path.is_relative_to(SOURCE.resolve()) and sha(path)==wav["sha256"]
    return provenance


def filter_signal(signal,hp=130,lp=3200):
    count=1<<(len(signal)*2-1).bit_length();frequencies=np.fft.rfftfreq(count,1/SR)
    transfer=1/np.sqrt(1+(frequencies/lp)**8)
    if hp: transfer*=frequencies**2/np.sqrt(frequencies**4+hp**4)
    return np.fft.irfft(np.fft.rfft(signal,count)*transfer,count)[:len(signal)]


def region(path,start,end):
    original=decode(path);raw=original[round(start*SR):round(end*SR)]
    assert len(raw)>=round(.09*SR)
    clean=filter_signal(raw-raw.mean());gain=.10/max(1e-12,rms(clean));clean*=gain
    return raw,clean,dict(source=str(path.relative_to(ROOT)),source_sha256=sha(path),start_seconds=start,end_seconds=end,
                          highpass_hz=130,lowpass_hz=3200,pre_gain_rms=rms(clean)/gain,level_match_gain=gain)


def texture(count,rubber,bubble,seed):
    rng=np.random.default_rng(seed);grain=round(.060*SR);hop=round(.015*SR);window=np.hanning(grain)
    signal=np.zeros(count+grain);weight=np.zeros_like(signal)
    for at in range(0,count,hop):
        fragments=[]
        for source in (rubber,bubble):
            start=int(rng.integers(0,len(source)-grain+1));fragment=source[start:start+grain].copy()
            if rng.random()<.20: fragment=fragment[::-1]*.65
            fragments.append(fragment)
        signal[at:at+grain]+=(.75*fragments[0]+.25*fragments[1])*window
        weight[at:at+grain]+=window
    signal/=np.maximum(weight,1e-8)
    return signal[:count]


def resonate(excitation,frequency):
    # A linear, recording-excited instrument. No oscillator bypass reaches the mix.
    t=np.arange(round(3.60*SR))/SR
    kernel=sum(g*np.sin(2*np.pi*frequency*h*t)*np.exp(-t/decay)
               for h,g,decay in [(1,1,.60),(2,.14,.25),(3,.05,.14),(4,.018,.10)])
    count=1<<(len(excitation)+len(kernel)-2).bit_length()
    result=np.fft.irfft(np.fft.rfft(excitation,count)*np.fft.rfft(kernel,count),count)
    return filter_signal(result[:len(excitation)],hp=0)


def envelope(count,gate):
    t=np.arange(count)/SR
    attack=np.sin(np.minimum(1,t/ATTACK)*np.pi/2)**2
    release=np.cos(np.clip((t-gate)/RELEASE,0,1)*np.pi/2)**2
    sag=1-.07*np.minimum(1,t/max(.1,gate))
    return attack*release*sag


def pitch(signal,gate,target):
    x=signal[round(.075*SR):round((gate-.035)*SR)]
    assert len(x)>SR*.2
    x=x-x.mean();window=x*np.hanning(len(x));count=1<<19
    power=np.abs(np.fft.rfft(window,count))**2;hz=np.fft.rfftfreq(count,1/SR)
    choices=np.flatnonzero((hz>=150)&(hz<=1500));index=choices[np.argmax(power[choices])]
    values=np.log(np.maximum(power[index-1:index+2],1e-30));offset=.5*(values[0]-values[2])/(values[0]-2*values[1]+values[2])
    measured=(index+offset)*SR/count
    outside=(hz>=150)&(hz<=2500)&(np.abs(hz-measured)>measured*.05)
    dominance=10*math.log10(power[index]/max(1e-30,float(power[outside].max())))
    # Independent time-domain periodicity estimate, not another target-bin picker.
    spectrum=np.fft.rfft(window,count);correlation=np.fft.irfft(spectrum*np.conj(spectrum),count)
    # Regress successive period peaks with a free intercept. A single first-lag
    # peak is biased by changing recorded-source colour and finite envelopes.
    period=SR/measured;peaks=[]
    for order in range(1,9):
        lo,hi=round((order-.15)*period),round((order+.15)*period)
        lag=lo+int(np.argmax(correlation[lo:hi]));a,b,c=correlation[lag-1:lag+2]
        peaks.append(lag+.5*(a-c)/(a-2*b+c))
    slope,intercept=np.polyfit(np.arange(1,9),peaks,1)
    autocorrelation_hz=SR/slope
    return dict(spectral_hz=float(measured),spectral_error_cents=1200*math.log2(measured/target),
                autocorrelation_hz=float(autocorrelation_hz),autocorrelation_error_cents=1200*math.log2(autocorrelation_hz/target),
                periodicity=float(correlation[round(peaks[0])]/correlation[0]),dominance_db=dominance,
                autocorrelation_peak_residual_samples=float(np.max(np.abs(np.array(peaks)-(np.arange(1,9)*slope+intercept)))),
                method="global150–1500Hz spectral maximum + eight-period autocorrelation regression")


def note(frequency,gate,instrument):
    length=round((gate+RELEASE)*SR)
    # One calibrated source-derived instrument across the phrase, like a sampler;
    # independently random resonator excitations can obscure a note's fundamental.
    speed=frequency/440
    raw=np.interp(np.arange(0,len(instrument),speed),np.arange(len(instrument)),instrument)
    corrections=[]
    for _ in range(5):
        sound=filter_signal(raw[:length],hp=0)*envelope(length,gate);measurement=pitch(sound,gate,frequency)
        assert measurement["dominance_db"]>5 and measurement["periodicity"]>.85, measurement
        if abs(measurement["spectral_error_cents"])<=2: break
        speed=frequency/measurement["spectral_hz"];corrections.append(speed)
        assert abs(1200*math.log2(speed))<100,measurement
        raw=np.interp(np.arange(0,len(raw),speed),np.arange(len(raw)),raw)
        assert len(raw)>=length
    gain=10**(-16/20)/max(1e-12,float(np.max(np.abs(sound))));sound*=gain
    return sound,dict(calibration_gain=gain,pitch_correction_speeds=corrections,pre_calibration_peak_dbfs=db(np.max(np.abs(sound))/gain))


def add_cyclic(destination,sound,start):
    indices=(start+np.arange(len(sound)))%len(destination);np.add.at(destination,indices,sound)


def meter(path):
    result=subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",str(path),"-af","loudnorm=I=-30:TP=-3:LRA=11:print_format=json","-f","null","-"],capture_output=True,text=True,check=True)
    values=json.loads(result.stderr[result.stderr.rfind("{"):result.stderr.rfind("}")+1])
    return dict(integrated_lufs=float(values["input_i"]),true_peak_dbtp=float(values["input_tp"]),loudness_range_lu=float(values["input_lra"]),meter_only_no_normalization=True)


def main():
    provenance=sources();before=preserved();OUT.mkdir(parents=True,exist_ok=True);bank=OUT/"note-bank";bank.mkdir(exist_ok=True)
    raw,rubber,rubber_info=region(SOURCE/"squeak_wavs/squeak toy - squeak2.wav",.075,.315)
    _,bubble,bubble_info=region(SOURCE/"bubbles-single2.wav",.085,.315)
    assert np.array_equal(resonate(np.zeros(20000),440),np.zeros(20000)),"hidden source-independent lead"
    ablation_a=texture(20000,rubber,bubble,SEED);ablation_b=texture(20000,bubble,bubble,SEED)
    assert not np.array_equal(resonate(ablation_a,440),resonate(ablation_b,440)),"source replacement did not change instrument"
    warmup=round(.8*SR)
    instrument=resonate(texture(round(2.8*SR),rubber,bubble,SEED+1),440)[warmup:]
    melody=np.zeros((FRAMES,2));gate_mask=np.zeros(FRAMES,dtype=bool);support_mask=gate_mask.copy();ledger=[]
    first_note=None;serial=0
    for bar,events in enumerate(BARS):
        for local_beat,name,gate_beats in events:
            serial+=1;beat=bar*4+local_beat;start=round(beat*BEAT);gate=gate_beats*BEAT/SR
            sound,recipe=note(NOTES[name],gate,instrument)
            path=bank/f"{serial:02d}-{name}.wav";pcm(path,sound);sound=read_pcm(path)
            measured=pitch(sound,gate,NOTES[name]);assert abs(measured["spectral_error_cents"])<=5 and abs(measured["autocorrelation_error_cents"])<=12,measured
            velocity=.88 if bar==4 and local_beat==.5 else [.98,.92,1,.95][serial%4]
            pan=.055*math.sin(2*math.pi*beat/32)
            angle=(pan+1)*math.pi/4;gains=np.array([math.cos(angle),math.sin(angle)])*math.sqrt(2)
            add_cyclic(melody,sound[:,None]*gains*velocity,start)
            gate_mask[(start+np.arange(round(gate*SR)))%FRAMES]=True
            support_mask[(start+np.arange(len(sound)))%FRAMES]=True
            ledger.append(dict(bar=bar+1,local_beat=local_beat,beat=beat,time_seconds=start/SR,note=name,frequency_hz=NOTES[name],gate_beats=gate_beats,
                               gate_frames=round(gate*SR),release_frames=round(RELEASE*SR),bank_file=str(path.relative_to(OUT)),bank_sha256=sha(path),velocity=velocity,pan=pan,pitch=measured,**recipe))
            if first_note is None:first_note=sound.copy()
    assert serial==27 and int(gate_mask.sum())==840000
    harmony=np.zeros_like(melody);dyads=[(0,8,174.6141157,261.6255653),(8,8,146.83238396,220),(16,8,116.5409404,174.6141157),(24,4,130.8127827,195.997718),(28,4,174.6141157,261.6255653)]
    for beat,beats,first,second in dyads:
        duration=beats*BEAT/SR+.2;t=np.arange(round(duration*SR))/SR
        env=np.minimum(1,t/.65)*np.minimum(1,(duration-t)/.65)
        sound=(np.sin(2*np.pi*first*t)+np.sin(2*np.pi*second*t+.3))*np.maximum(0,env)
        add_cyclic(harmony,sound[:,None]*np.ones((1,2)),round(beat*BEAT-.1*SR))
    harmony_gain=rms(melody[gate_mask])*10**(-14/20)/max(1e-12,rms(harmony[gate_mask]));harmony*=harmony_gain
    hierarchy=db(rms(harmony[gate_mask])/rms(melody[gate_mask]));assert abs(hierarchy+14)<1e-8
    dry=melody+harmony;room=np.zeros_like(dry);taps=[(.037,.30),(.055,.23),(.081,.18)]
    taps += [(float(d),float(.14*math.exp(-math.log(1000)*(d-.08)/.8))) for d in np.arange(.095,.915,.019)]
    total=sum(g for _,g in taps)
    for delay,gain in taps:
        for channel in range(2):room[:,channel]+=np.roll(dry[:,channel],round((delay+channel*.0013)*SR))*gain/total
    mix=dry+.12*room
    main_path=OUT/"garden-melodic-audition-27s.wav";authoritative=pcm(main_path,mix)
    mono_path=OUT/"garden-melodic-audition-27s-mono.wav";mono=pcm(mono_path,authoritative.mean(axis=1))
    assert len(authoritative)==FRAMES and np.max(np.abs(mono-authoritative.mean(axis=1)))<=1/32767
    seam_path=OUT/"garden-melodic-seam-8s.wav";seam=np.tile(np.concatenate([authoritative[-2*SR:],authoritative[:2*SR]]),(2,1));pcm(seam_path,seam)
    raw=raw*min(1,10**(-16/20)/np.max(np.abs(raw)));raw_stereo=np.repeat(raw[:,None],2,axis=1)
    silence=np.zeros((round(.65*SR),2));single=np.repeat(first_note[:,None],2,axis=1);phrase=authoritative[:8*BEAT]
    diagnostic=np.concatenate([raw_stereo,silence,single,silence,phrase]);diagnostic_path=OUT/"source-transformation-diagnostic.wav";pcm(diagnostic_path,diagnostic)
    measurements={};output_hashes={}
    for path in (main_path,mono_path,seam_path,diagnostic_path):
        measurements[path.name]=meter(path);assert measurements[path.name]["true_peak_dbtp"] < -3
        subprocess.run(["ffmpeg","-y","-v","error","-i",str(path),"-c:a","libmp3lame","-b:a","192k",str(path.with_suffix(".mp3"))],check=True)
        output_hashes[path.name]=sha(path);output_hashes[path.with_suffix(".mp3").name]=sha(path.with_suffix(".mp3"))
    assert np.array_equal(read_pcm(seam_path),seam) and preserved()==before,"source/v3 mutation or seam mismatch"
    report=dict(title="Garden v4 transformed toy melody",frames=FRAMES,seconds=FRAMES/SR,sample_rate=SR,bpm=72,bars=8,note_count=serial,
      provenance=provenance,preserved_hashes=before,processing=dict(sources=[rubber_info,bubble_info],grain_ms=60,overlap=.75,rubber_blend=.75,bubble_blend=.25,
      reversed_grain_probability=.20,reversed_grain_gain=.65,attack_ms=45,release_ms=140,lowpass_hz=3200,
      source_instrument_hz=440,source_texture_seed=SEED+1,pitched_by="resample actual source-excited A4 instrument before exact envelope",
      resonator_modes=[[1,1,.60],[2,.14,.25],[3,.05,.14],[4,.018,.10]],no_independent_melody_oscillator=True,zero_excitation_silence=True,source_replacement_changes_voice=True),
      notes=ledger,dyad_windows=dyads,harmony_gain=harmony_gain,harmony_relative_rms_db=hierarchy,harmony_mask="same exact note-gate mask for numerator and denominator",
      melodic_gate_occupancy=float(gate_mask.mean()),melodic_release_support_occupancy=float(support_mask.mean()),decorative_foley_occupancy=0,
      room=dict(nominal_common_delay_offset_ms=14,first_wet_reflection_ms=37,right_first_wet_reflection_ms=38.3,
                early_reflections_after_nominal_offset_ms=[23,41,67],no_standalone_14ms_tap=True,tail_t60_seconds=.8,send=.12,cyclic=True,right_channel_extra_ms=1.3,
                taps_seconds_and_normalized_gain=[[delay,gain/total]for delay,gain in taps]),measurements=measurements,
      sample_peak_dbfs=db(np.max(np.abs(authoritative))),mono_sample_peak_dbfs=db(np.max(np.abs(mono))),clipped_samples=0,nonfinite_samples=0,
      mono_per_channel_energy_db=db(rms(mono)/rms(authoritative)),dc_per_channel=authoritative.mean(axis=0).tolist(),boundary_jump=(authoritative[0]-authoritative[-1]).tolist(),
      diagnostic=[dict(label="raw rubber body fragment",start=0,seconds=len(raw)/SR),dict(label="transformed A4 note",start=(len(raw)+len(silence))/SR,seconds=len(single)/SR),
                  dict(label="first complete two-bar phrase",start=(len(raw)+len(single)+2*len(silence))/SR,seconds=len(phrase)/SR)],
      output_sha256=output_hashes,generator_sha256=sha(Path(__file__)),seed=SEED,final_mix_gain=1,final_loudness_normalization=False,uploaded=False,runtime_mapped=False,
      limits=["No listening or subjective softness/seam approval claimed.","Pitch estimates are measured spectral/periodicity evidence, not a universal auditory guarantee.","Gate and release support occupancy are separate; the exact score is preserved."])
    (OUT/"audition-report.json").write_text(json.dumps(report,indent=2,allow_nan=False),encoding="utf-8")
    print(json.dumps(dict(measurements=measurements,gate_occupancy=report["melodic_gate_occupancy"],release_occupancy=report["melodic_release_support_occupancy"],max_pitch_error_cents=max(abs(n["pitch"]["spectral_error_cents"]) for n in ledger)),indent=2))


if __name__=="__main__":main()
