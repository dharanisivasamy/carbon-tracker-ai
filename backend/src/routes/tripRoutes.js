import { Router } from 'express';
import { body } from 'express-validator';
import { createTrip,listTrips,getTrip,deleteTrip,summary,reports,recommendations } from '../controllers/tripController.js';
import { requireAuth } from '../middleware/authMiddleware.js';
const r=Router();r.use(requireAuth);r.get('/summary',summary);r.get('/reports',reports);r.get('/recommendations',recommendations);r.post('/',[body('transportMode').isIn(['walking','cycling','bike','car','bus','train','flight']),body('distance').isFloat({min:0}),body('date').isISO8601()],createTrip);r.get('/',listTrips);r.get('/:id',getTrip);r.delete('/:id',deleteTrip);export default r;
