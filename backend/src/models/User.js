import bcrypt from 'bcryptjs'; import mongoose from 'mongoose';
const schema = new mongoose.Schema({name:{type:String,required:true,trim:true},email:{type:String,required:true,unique:true,lowercase:true,trim:true},password:{type:String,required:true,minlength:8,select:false}},{timestamps:true});
schema.pre('save', async function(next) { if (!this.isModified('password')) return next(); this.password=await bcrypt.hash(this.password,12); next(); });
export default mongoose.model('User', schema);
