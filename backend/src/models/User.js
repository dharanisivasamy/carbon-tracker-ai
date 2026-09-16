import bcrypt from 'bcryptjs'; import mongoose from 'mongoose';
const schema = new mongoose.Schema({name:{type:String,required:true,trim:true},email:{type:String,required:true,unique:true,lowercase:true,trim:true},password:{type:String,minlength:8,select:false,required:function(){return this.authProvider!=='google'}},googleUid:{type:String,unique:true,sparse:true},authProvider:{type:String,enum:['password','google'],default:'password'}},{timestamps:true});
schema.pre('save', async function(next) { if (!this.isModified('password')) return next(); this.password=await bcrypt.hash(this.password,12); next(); });
export default mongoose.model('User', schema);
