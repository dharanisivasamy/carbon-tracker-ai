import { validationResult } from 'express-validator';

const mlUrl = () => process.env.ML_INFERENCE_URL || 'http://127.0.0.1:8000';

/** Thin HTTP proxy: inference stays independently deployable in Python. */
export async function classifyTrip(req, res, next) {
  const started = performance.now();
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, message: errors.array()[0].msg });
    const response = await fetch(`${mlUrl()}/classify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(req.body),
      signal: AbortSignal.timeout(1800), // leave margin under Flutter's 2 s fallback
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) return res.status(502).json({ success: false, message: payload?.detail || 'ML inference service failed' });
    const latencyMs = Math.round(performance.now() - started);
    // Structured log for later Objective-5 analysis. Do not store this in Trip.
    console.info(JSON.stringify({ event: 'ml_classification', timestamp: new Date().toISOString(), userId: req.userId, features: req.body, prediction: payload.predicted_class, confidence: payload.confidence, latencyMs }));
    res.json({ success: true, data: payload });
  } catch (error) {
    const latencyMs = Math.round(performance.now() - started);
    console.warn(JSON.stringify({ event: 'ml_classification_failed', timestamp: new Date().toISOString(), userId: req.userId, features: req.body, latencyMs, error: error.name }));
    if (error.name === 'TimeoutError' || error.name === 'AbortError') return res.status(504).json({ success: false, message: 'ML inference timed out' });
    next(error);
  }
}
