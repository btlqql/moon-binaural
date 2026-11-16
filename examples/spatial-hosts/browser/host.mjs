async function connect(context) {
  await context.audioWorklet.addModule("./worklet.js");
  const spatial = new AudioWorkletNode(context, "moon-spatial", {
    numberOfInputs: 1,
    numberOfOutputs: 1,
    outputChannelCount: [2],
    channelCount: 1,
    channelCountMode: "explicit",
  });
  spatial.connect(context.destination);
  return spatial;
}

globalThis.verifySpatialWorklet = async () => {
  const context = new OfflineAudioContext(2, 1024, 48000);
  const spatial = await connect(context);
  const clip = context.createBuffer(1, 768, 48000);
  const input = clip.getChannelData(0);
  input[0] = 0.5;
  input[512] = 0.5;
  const source = context.createBufferSource();
  source.buffer = clip;
  source.connect(spatial);
  source.start();
  spatial.parameters.get("yaw").setValueAtTime(-0.8, 384 / 48000);
  const result = await context.startRendering();
  return {
    left: Array.from(result.getChannelData(0)),
    right: Array.from(result.getChannelData(1)),
    sample_rate: result.sampleRate,
  };
};

const play = document.querySelector("#play");
const yaw = document.querySelector("#yaw");
const status = document.querySelector("#status");
let context;
let oscillator;
play.onclick = async () => {
  play.disabled = true;
  try {
    if (context) {
      oscillator.stop();
      await context.close();
      context = undefined;
      play.textContent = "Start beacon";
      return;
    }
    context = new AudioContext({sampleRate: 48000});
    await context.resume();
    const spatial = await connect(context);
    const orientation = spatial.parameters.get("yaw");
    const update = () => {
      orientation.setValueAtTime(Number(yaw.value) * Math.PI / 180, context.currentTime);
    };
    yaw.oninput = update;
    update();
    const level = context.createGain();
    level.gain.value = 0.15;
    oscillator = context.createOscillator();
    oscillator.frequency.value = 370;
    oscillator.connect(level).connect(spatial);
    oscillator.start();
    play.textContent = "Stop beacon";
    status.textContent = "";
  } catch (error) {
    if (context && context.state !== "closed") await context.close();
    context = undefined;
    status.textContent = error.message;
  } finally {
    if (!context) yaw.oninput = null;
    play.disabled = false;
  }
};
