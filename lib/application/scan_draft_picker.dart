import 'package:flutter/material.dart';
import 'scan_drafts.dart';

class ScanDraftPicker extends StatefulWidget {
  final ScanDrafts store;
  const ScanDraftPicker({super.key, required this.store});
  @override
  State<ScanDraftPicker> createState() => _ScanDraftPickerState();
}
class _ScanDraftPickerState extends State<ScanDraftPicker> {
  List<DraftSummary>? items;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await widget.store.list();
      if(mounted) { setState(()=>items=result); }
    } catch(_) {
      if(mounted) { setState(()=>error='Could not read saved drafts. Check storage access.'); }
    }
  }
  Future<void> remove(DraftSummary draft) async {
    final yes = await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('Delete saved draft?'),
      content:const Text('This deletes the local draft copy. Your original files are unchanged. This does not promise secure physical erasure.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Keep draft')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete draft'))],
    ));
    if(yes!=true) { return; }
    try { await widget.store.delete(draft.id); await load(); }
    catch(_) { if(mounted) { setState(()=>error='Could not delete the draft. Check storage access.'); } }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title:const Text('Restore a scan draft'),
    content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('Expired drafts are removed when you open this list. Drafts stay on this device.'),
      if(error!=null) Text(error!),
      if(items==null && error==null) const LinearProgressIndicator(),
      if(items?.isEmpty??false) const Padding(padding:EdgeInsets.all(16),child:Text('No saved drafts.')),
      for(final item in items??<DraftSummary>[]) ListTile(
        title:Text('${item.pages} pages · ${item.created.toLocal().toString().split('.').first}'),
        subtitle:Text('Expires ${item.expires.toLocal().toString().split(' ').first}'),
        onTap:()=>Navigator.pop(context,item.id),
        trailing:IconButton(tooltip:'Delete this draft',onPressed:()=>remove(item),icon:const Icon(Icons.delete_outline)),
      ),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))],
  );
}
