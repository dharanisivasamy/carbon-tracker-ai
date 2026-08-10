export const emissionFactors = Object.freeze({ walking: 0, cycling: 0, bike: 0.05, car: 0.21, bus: 0.10, train: 0.04, flight: 0.25 });

export function calculateCarbon(transportMode, distance) {
  if (!(transportMode in emissionFactors)) throw new Error('Invalid transport mode');
  const safeDistance = Number(distance);
  if (!Number.isFinite(safeDistance) || safeDistance < 0) throw new Error('Distance must be zero or greater');
  return { transportMode, distance: safeDistance, carbonEmission: Number((safeDistance * emissionFactors[transportMode]).toFixed(4)) };
}
