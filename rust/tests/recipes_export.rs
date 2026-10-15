use studio_core::{export,model::*,recipe::Recipe};
fn prepared(data:Vec<u8>)->PreparedOutput{PreparedOutput{info:OutputInfo{bytes:data.len() as u64,format:"json".into(),width:None,height:None,pages:None,quality:None,findings:vec![]},data}}
#[test]
fn crop_roundtrip_and_checked_bounds(){
 let value=serde_json::json!({"schema_version":2,"name":"Crop","revision_date":"2026-10-16","steps":[{"type":"crop","x":1,"y":1,"width":2,"height":3},{"type":"rename","filename":"photo.png"},{"type":"export","format":"png"}]});
 let bytes=value.to_string().into_bytes();let dir=tempfile::tempdir().unwrap();
 export::save_copy(dir.path(),"ছবি.json",&prepared(bytes.clone())).unwrap();assert!(export::save_copy(dir.path(),"ছবি.json",&prepared(bytes.clone())).is_err());
 let source=include_bytes!("fixtures/orientation-6.jpg");let r=Recipe::parse(&bytes).unwrap();let result=r.run(source).unwrap();
 let expected=studio_core::photo::decode(source).unwrap().crop_imm(1,1,2,3).to_rgba8();assert_eq!(image::load_from_memory(&result.data).unwrap().to_rgba8(),expected);
 for (field,new_value) in [("x",serde_json::json!(12000)),("width",serde_json::json!(0))]{let mut bad=value.clone();bad["steps"][0][field]=new_value;assert!(Recipe::parse(bad.to_string().as_bytes()).is_err());}
 let mut bad=value.clone();bad["schema_version"]=serde_json::json!(1);assert!(Recipe::parse(bad.to_string().as_bytes()).is_err());
 let mut bad=value;bad["steps"][1]["filename"]=serde_json::json!("photo.jpg");assert!(Recipe::parse(bad.to_string().as_bytes()).is_err());
}
