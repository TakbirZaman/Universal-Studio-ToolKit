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
  bool clearing = false;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final result = await widget.store.list();
      if(mounted) { setState(() { items=result; error=null; }); }
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
  Future<void> clearDrafts() async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete all saved scan drafts?'),
      content: const Text('This removes all local scan drafts, including incomplete or damaged copies that cannot be restored. Your original files and current open scan are unchanged. This does not promise secure physical erasure.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep drafts')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all drafts')),
      ],
    ));
    if (yes != true || !mounted) { return; }
    setState(() { clearing = true; error = null; });
    try {
      await widget.store.clear();
      await load();
    } catch (_) {
      if (mounted) { setState(() => error = 'Some drafts could not be deleted. Check storage access and try again.'); }
    } finally {
      if (mounted) { setState(() => clearing = false); }
    }
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
        onTap:clearing ? null : ()=>Navigator.pop(context,item.id),
        trailing:IconButton(tooltip:'Delete this draft',onPressed:clearing ? null : ()=>remove(item),icon:const Icon(Icons.delete_outline)),
      ),
    ]))),
    actions:[
      TextButton(onPressed:clearing ? null : clearDrafts,child:const Text('Delete all saved drafts')),
      TextButton(onPressed:clearing ? null : ()=>Navigator.pop(context),child:const Text('Close')),
    ],
  );
}
