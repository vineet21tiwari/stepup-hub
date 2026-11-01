import { useEffect, useMemo, useRef, useState } from "react";

// Lets the user either pick a video file or record one live via the camera.
// Calls onChange(file) with a File object, or onChange(null) to clear.
export default function VideoCapture({ file, onChange }) {
  const [mode, setMode] = useState("idle"); // idle | camera
  const [recording, setRecording] = useState(false);
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const recorderRef = useRef(null);
  const chunksRef = useRef([]);

  const previewUrl = useMemo(() => (file ? URL.createObjectURL(file) : null), [file]);
  useEffect(() => () => previewUrl && URL.revokeObjectURL(previewUrl), [previewUrl]);
  useEffect(() => () => stopCamera(), []);

  function stopCamera() {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }

  function handleFileInput(e) {
    const f = e.target.files?.[0];
    if (f) onChange(f);
    e.target.value = "";
  }

  async function startCamera() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      streamRef.current = stream;
      setMode("camera");
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
    } catch {
      alert("Couldn't access your camera/microphone. Check browser permissions, or upload a video file instead.");
    }
  }

  function startRecording() {
    chunksRef.current = [];
    const recorder = new MediaRecorder(streamRef.current);
    recorder.ondataavailable = (e) => {
      if (e.data.size > 0) chunksRef.current.push(e.data);
    };
    recorder.onstop = () => {
      const blob = new Blob(chunksRef.current, { type: "video/webm" });
      onChange(new File([blob], `intro-${Date.now()}.webm`, { type: "video/webm" }));
      stopCamera();
      setMode("idle");
      setRecording(false);
    };
    recorder.start();
    recorderRef.current = recorder;
    setRecording(true);
  }

  function stopRecording() {
    recorderRef.current?.stop();
  }

  function cancelCamera() {
    stopCamera();
    setMode("idle");
    setRecording(false);
  }

  if (file) {
    return (
      <div className="video-capture">
        <video src={previewUrl} controls className="video-capture-preview" />
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => onChange(null)}>
          Remove video
        </button>
      </div>
    );
  }

  if (mode === "camera") {
    return (
      <div className="video-capture">
        <video ref={videoRef} className="video-capture-preview" muted playsInline />
        <div className="btn-group">
          {!recording ? (
            <button type="button" className="btn btn-primary btn-sm" onClick={startRecording}>
              Start recording
            </button>
          ) : (
            <button type="button" className="btn btn-primary btn-sm" onClick={stopRecording}>
              Stop recording
            </button>
          )}
          <button type="button" className="btn btn-ghost btn-sm" onClick={cancelCamera}>
            Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="video-capture">
      <div className="btn-group">
        <label className="btn btn-ghost btn-sm video-capture-file-label">
          Upload video file
          <input type="file" accept="video/*" onChange={handleFileInput} hidden />
        </label>
        <button type="button" className="btn btn-ghost btn-sm" onClick={startCamera}>
          Record with camera
        </button>
      </div>
    </div>
  );
}
