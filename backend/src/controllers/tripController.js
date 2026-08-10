import { validationResult } from 'express-validator';

import Trip from '../models/Trip.js';
import { emissionFactors, calculateCarbon } from '../services/carbonService.js';

const modes = ['walking', 'cycling', 'bike', 'car', 'bus', 'train', 'flight'];
const fail = (res, message, status = 400) => res.status(status).json({ success: false, message });
const day = date => new Date(date.getFullYear(), date.getMonth(), date.getDate());
const round = value => Number(value.toFixed(2));

const weekly = async userId => {
  const today = day(new Date());
  const start = new Date(today);
  start.setDate(start.getDate() - 6);
  const trips = await Trip.find({ userId, date: { $gte: start } });
  return Array.from({ length: 7 }, (_, i) => {
    const date = new Date(start);
    date.setDate(date.getDate() + i);
    return trips
      .filter(trip => day(trip.date).getTime() === date.getTime())
      .reduce((sum, trip) => sum + trip.carbonEmission, 0);
  });
};

const analyzeTrips = trips => {
  const byMode = Object.fromEntries(modes.map(mode => [mode, { tripCount: 0, distance: 0, carbon: 0 }]));
  let totalDistance = 0;
  let totalCarbon = 0;

  for (const trip of trips) {
    const entry = byMode[trip.transportMode];
    if (!entry) continue;
    entry.tripCount += 1;
    entry.distance += trip.distance;
    entry.carbon += trip.carbonEmission;
    totalDistance += trip.distance;
    totalCarbon += trip.carbonEmission;
  }

  const transportModes = Object.fromEntries(
    modes.map(mode => {
      const entry = byMode[mode];
      return [mode, {
        tripCount: entry.tripCount,
        tripPercentage: trips.length ? round((entry.tripCount / trips.length) * 100) : 0,
        distanceKm: round(entry.distance),
        carbonKg: round(entry.carbon),
        carbonPercentage: totalCarbon ? round((entry.carbon / totalCarbon) * 100) : 0,
      }];
    }),
  );

  const rankedByCarbon = modes.filter(mode => byMode[mode].carbon > 0).sort((a, b) => byMode[b].carbon - byMode[a].carbon);
  const rankedByTrips = modes.filter(mode => byMode[mode].tripCount > 0).sort((a, b) => byMode[b].tripCount - byMode[a].tripCount);
  const now = new Date();
  const recentStart = new Date(now);
  recentStart.setDate(recentStart.getDate() - 29);
  const recentTrips = trips.filter(trip => trip.date >= recentStart);
  const currentWeekStart = day(now);
  currentWeekStart.setDate(currentWeekStart.getDate() - 6);
  const previousWeekStart = new Date(currentWeekStart);
  previousWeekStart.setDate(previousWeekStart.getDate() - 7);
  const currentWeekCarbon = trips.filter(trip => trip.date >= currentWeekStart).reduce((sum, trip) => sum + trip.carbonEmission, 0);
  const previousWeekCarbon = trips
    .filter(trip => trip.date >= previousWeekStart && trip.date < currentWeekStart)
    .reduce((sum, trip) => sum + trip.carbonEmission, 0);

  return {
    totalTrips: trips.length,
    totalDistanceKm: round(totalDistance),
    totalCarbonKg: round(totalCarbon),
    averageCarbonPerTripKg: trips.length ? round(totalCarbon / trips.length) : 0,
    averageDistancePerTripKm: trips.length ? round(totalDistance / trips.length) : 0,
    transportModes,
    highestEmissionTransportMode: rankedByCarbon[0] ?? null,
    mostFrequentTransportMode: rankedByTrips[0] ?? null,
    lowestCarbonPracticalMode: 'walking/cycling',
    recentTravelPatterns: {
      tripCount: recentTrips.length,
      carbonKg: round(recentTrips.reduce((sum, trip) => sum + trip.carbonEmission, 0)),
    },
    weeklyCarbonTrend: {
      currentWeekKg: round(currentWeekCarbon),
      previousWeekKg: round(previousWeekCarbon),
      changeKg: round(currentWeekCarbon - previousWeekCarbon),
    },
  };
};

const basedOn = (analysis, mode) => ({
  transportMode: mode,
  carbonShare: analysis.transportModes[mode].carbonPercentage / 100,
  tripCount: analysis.transportModes[mode].tripCount,
});

const createRecommendations = (trips, analysis) => {
  if (analysis.totalTrips < 3) {
    return [{
      id: 'track-more-trips',
      title: 'Track a few more trips',
      description: `You have tracked ${analysis.totalTrips} ${analysis.totalTrips === 1 ? 'trip' : 'trips'} so far. More travel data will make your insights more personal.`,
      category: 'Getting started',
      priority: 'low',
      reason: 'Personalised travel patterns become more meaningful after several tracked trips.',
    }];
  }

  const recommendations = [];
  const highest = analysis.highestEmissionTransportMode;
  const car = analysis.transportModes.car;
  const flight = analysis.transportModes.flight;
  const publicTransportTrips = analysis.transportModes.bus.tripCount + analysis.transportModes.train.tripCount;
  const activeTrips = analysis.transportModes.walking.tripCount + analysis.transportModes.cycling.tripCount;

  if (highest === 'car') {
    const shortCarTrips = trips.filter(trip => trip.transportMode === 'car' && trip.distance <= 5);
    const estimatedSaving = shortCarTrips.length
      ? shortCarTrips.reduce((sum, trip) => sum + trip.carbonEmission, 0)
      : car.distanceKm * (emissionFactors.car - emissionFactors.bus) * 0.2;
    recommendations.push({
      id: 'reduce-car-emissions',
      title: 'Reduce your car emissions',
      description: `You made ${car.tripCount} car trips, accounting for ${car.carbonPercentage}% of your tracked transport emissions. For suitable short trips, consider walking, cycling, bus, or train.`,
      category: 'Transport',
      priority: 'high',
      estimatedSavingKg: round(estimatedSaving),
      reason: shortCarTrips.length
        ? `${shortCarTrips.length} of your car trips were 5 km or shorter.`
        : 'Car trips are your largest tracked source of transport emissions.',
      basedOn: basedOn(analysis, 'car'),
    });
  }

  if (highest === 'flight' || flight.carbonPercentage >= 35) {
    const estimatedSaving = flight.distanceKm * (emissionFactors.flight - emissionFactors.train) * 0.2;
    recommendations.push({
      id: 'reduce-flight-emissions',
      title: 'Consider lower-carbon journeys where suitable',
      description: `Flights account for ${flight.carbonPercentage}% of your tracked transport emissions across ${flight.tripCount} trips. For suitable journeys, train can be a lower-carbon alternative.`,
      category: 'Transport',
      priority: 'high',
      estimatedSavingKg: round(estimatedSaving),
      reason: 'This estimate compares moving 20% of your tracked flight distance to train using the app’s carbon factors.',
      basedOn: basedOn(analysis, 'flight'),
    });
  }

  if (!recommendations.length && publicTransportTrips > 0 && (highest === 'bus' || highest === 'train' || publicTransportTrips >= activeTrips)) {
    const mode = highest === 'train' ? 'train' : 'bus';
    const data = analysis.transportModes[mode];
    recommendations.push({
      id: 'keep-using-public-transport',
      title: 'Your lower-carbon choices are adding up',
      description: `You recorded ${publicTransportTrips} bus or train trips. ${mode[0].toUpperCase()}${mode.slice(1)} is helping keep your tracked emissions lower than many private-car journeys.`,
      category: 'Progress',
      priority: 'low',
      reason: `${data.tripCount} ${mode} trips account for ${data.tripPercentage}% of your tracked trips.`,
      basedOn: basedOn(analysis, mode),
    });
  }

  if (!recommendations.length && activeTrips >= analysis.totalTrips / 2) {
    const mode = analysis.transportModes.walking.tripCount >= analysis.transportModes.cycling.tripCount ? 'walking' : 'cycling';
    const data = analysis.transportModes[mode];
    recommendations.push({
      id: 'maintain-active-travel',
      title: 'Keep up your low-carbon travel',
      description: `${data.tripCount} of your tracked trips were by ${mode}. Maintaining walking and cycling for suitable journeys keeps your travel emissions low.`,
      category: 'Progress',
      priority: 'low',
      reason: `${mode[0].toUpperCase()}${mode.slice(1)} is your most frequently used low-carbon option.`,
      basedOn: basedOn(analysis, mode),
    });
  }

  if (!recommendations.length && highest) {
    const data = analysis.transportModes[highest];
    const alternative = highest === 'bike' ? 'cycling' : 'bus or train';
    const estimatedSaving = data.distanceKm * Math.max(0, emissionFactors[highest] - emissionFactors.train) * 0.2;
    recommendations.push({
      id: `reduce-${highest}-emissions`,
      title: `Reduce your ${highest} emissions`,
      description: `${data.tripCount} ${highest} trips produce ${data.carbonPercentage}% of your tracked transport emissions. Consider ${alternative} for suitable journeys.`,
      category: 'Transport',
      priority: 'medium',
      estimatedSavingKg: round(estimatedSaving),
      reason: `${highest[0].toUpperCase()}${highest.slice(1)} is your highest-emission transport mode.`,
      basedOn: basedOn(analysis, highest),
    });
  }

  if (analysis.weeklyCarbonTrend.previousWeekKg > 0 && analysis.weeklyCarbonTrend.changeKg < 0) {
    recommendations.push({
      id: 'weekly-progress',
      title: 'Your weekly carbon is trending down',
      description: `Your tracked travel emissions are ${round(Math.abs(analysis.weeklyCarbonTrend.changeKg))} kg CO₂ lower than the previous seven days.`,
      category: 'Progress',
      priority: 'low',
      reason: 'This compares your most recent seven days of recorded trips with the seven days before that.',
    });
  }

  return recommendations;
};

export async function createTrip(req, res, next) {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return fail(res, errors.array()[0].msg);
    const carbon = calculateCarbon(req.body.transportMode, req.body.distance);
    const trip = await Trip.create({ ...carbon, date: req.body.date, notes: req.body.notes, userId: req.userId });
    res.status(201).json({ success: true, data: trip });
  } catch (error) { next(error); }
}

export async function listTrips(req, res, next) {
  try {
    const query = { userId: req.userId };
    if (req.query.transportMode) query.transportMode = req.query.transportMode;
    if (req.query.search) query.notes = { $regex: req.query.search, $options: 'i' };
    const sort = { newest: { date: -1 }, oldest: { date: 1 }, highestCarbon: { carbonEmission: -1 } }[req.query.sort] || { date: -1 };
    res.json({ success: true, data: await Trip.find(query).sort(sort) });
  } catch (error) { next(error); }
}

export async function getTrip(req, res, next) { try { const trip = await Trip.findOne({ _id: req.params.id, userId: req.userId }); if (!trip) return fail(res, 'Trip not found', 404); res.json({ success: true, data: trip }); } catch (error) { next(error); } }
export async function deleteTrip(req, res, next) { try { const trip = await Trip.findOneAndDelete({ _id: req.params.id, userId: req.userId }); if (!trip) return fail(res, 'Trip not found', 404); res.json({ success: true, data: { id: req.params.id } }); } catch (error) { next(error); } }

export async function summary(req, res, next) {
  try {
    const trips = await Trip.find({ userId: req.userId }).sort({ date: -1 });
    const today = day(new Date()).getTime();
    res.json({ success: true, data: { todayCarbon: trips.filter(trip => day(trip.date).getTime() === today).reduce((sum, trip) => sum + trip.carbonEmission, 0), totalTrips: trips.length, totalDistance: trips.reduce((sum, trip) => sum + trip.distance, 0), recentTrips: trips.slice(0, 3), weeklyCarbon: await weekly(req.userId) } });
  } catch (error) { next(error); }
}

export async function reports(req, res, next) {
  try {
    const now = new Date(); let start = null;
    if (req.query.period === 'week') { start = day(now); start.setDate(start.getDate() - 6); } else if (req.query.period === 'month') start = new Date(now.getFullYear(), now.getMonth(), 1); else if (req.query.period && req.query.period !== 'allTime') return fail(res, 'Invalid period');
    const trips = await Trip.find({ userId: req.userId, ...(start ? { date: { $gte: start } } : {}) });
    const totalCarbon = trips.reduce((sum, trip) => sum + trip.carbonEmission, 0);
    const transportBreakdown = Object.fromEntries(modes.map(mode => [mode, trips.filter(trip => trip.transportMode === mode).reduce((sum, trip) => sum + trip.carbonEmission, 0)]));
    res.json({ success: true, data: { totalCarbon, totalTrips: trips.length, averageCarbon: trips.length ? totalCarbon / trips.length : 0, transportBreakdown, weeklyCarbon: await weekly(req.userId) } });
  } catch (error) { next(error); }
}

export async function recommendations(req, res, next) {
  try {
    const trips = await Trip.find({ userId: req.userId }).sort({ date: -1 });
    const analysis = analyzeTrips(trips);
    res.json({ success: true, data: createRecommendations(trips, analysis), analysis });
  } catch (error) { next(error); }
}
