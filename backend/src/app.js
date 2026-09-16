import cors from 'cors';import express from 'express';import authRoutes from './routes/authRoutes.js';import tripRoutes from './routes/tripRoutes.js';import {errorHandler,notFound} from './middleware/errorMiddleware.js';
const configuredClientOrigin=process.env.CLIENT_URL;
const localhostOrigin=/^http:\/\/(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$/;
const isDevelopment=process.env.NODE_ENV!=='production';
const app=express();app.use(cors({origin(origin,callback){const allowed=!origin||origin===configuredClientOrigin||(isDevelopment&&localhostOrigin.test(origin));callback(null,allowed);},credentials:true}));app.use(express.json());app.get('/api/health',(req,res)=>res.json({success:true,message:'Carbon Tracker API is running'}));app.use('/api/auth',authRoutes);app.use('/api/trips',tripRoutes);app.use(notFound);app.use(errorHandler);export default app;
