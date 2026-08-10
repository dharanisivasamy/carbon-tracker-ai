export function notFound(req,res) { res.status(404).json({success:false,message:'Route not found'}); }
export function errorHandler(error,req,res,next) { console.error(error); const status=error.status||500; res.status(status).json({success:false,message:error.message||'Internal server error'}); }
