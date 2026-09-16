import { Router } from 'express';
import { body } from 'express-validator';
import { createTrip,listTrips,getTrip,deleteTrip,summary,reports,recommendations } from '../controllers/tripController.js';
import { requireAuth } from '../middleware/authMiddleware.js';
import { classifyTrip } from '../controllers/mlController.js';
const featureFields=['avg_speed_kmh','speed_variance_kmh2','max_speed_kmh','distance_m'];
const r=Router();r.use(requireAuth);r.get('/summary',summary);r.get('/reports',reports);r.get('/recommendations',recommendations);r.post('/classify',featureFields.map(field=>body(field).isFloat({min:0})),classifyTrip);r.post('/',[body('transportMode').isIn(['walking','cycling','bike','car','bus','train','flight']),body('distance').isFloat({min:0}),body('date').isISO8601()],createTrip);r.get('/',listTrips);r.get('/:id',getTrip);r.delete('/:id',deleteTrip);export default r;
