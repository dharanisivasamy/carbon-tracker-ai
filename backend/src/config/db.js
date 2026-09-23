import mongoose from 'mongoose';
export async function connectDatabase() {
  const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!uri) throw new Error('Neither MONGO_URI nor MONGODB_URI is defined');
  await mongoose.connect(uri);
  console.log('MongoDB connected');
}
