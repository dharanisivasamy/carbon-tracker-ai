import mongoose from 'mongoose';
export const modes=['walking','cycling','bike','car','bus','train','flight'];
export default mongoose.model('Trip',new mongoose.Schema({userId:{type:mongoose.Schema.Types.ObjectId,ref:'User',required:true,index:true},transportMode:{type:String,enum:modes,required:true},distance:{type:Number,min:0,required:true},carbonEmission:{type:Number,min:0,required:true},date:{type:Date,required:true},notes:{type:String,trim:true,maxlength:1000}},{timestamps:true}));
