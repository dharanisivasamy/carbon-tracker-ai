import jwt from 'jsonwebtoken';
export function requireAuth(req,res,next) { const token=req.headers.authorization?.split(' ')[1]; if (!token) return res.status(401).json({success:false,message:'Unauthorized'}); try { req.userId=jwt.verify(token,process.env.JWT_SECRET).id; next(); } catch { res.status(401).json({success:false,message:'Unauthorized'}); } }
