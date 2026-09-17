import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../core/constants/prayer_types.dart';
import 'calendar_controller.dart';

class CalendarPicker extends ConsumerStatefulWidget {
  const CalendarPicker({super.key,this.qazaDates=const <DateTime>{},this.availablePrayersByDate,this.availabilityLoading=false,this.onMonthChanged});
  final Set<DateTime> qazaDates;
  final Map<DateTime,Set<PrayerType>>? availablePrayersByDate;
  final bool availabilityLoading;
  final ValueChanged<DateTime>? onMonthChanged;
  @override ConsumerState<CalendarPicker> createState()=>_CalendarPickerState();
}
class _CalendarPickerState extends ConsumerState<CalendarPicker>{
  late DateTime month;
  DateTime get today=>ref.read(calendarTodayProvider);
  bool same(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  @override void initState(){super.initState();month=DateTime(today.year,today.month,1);WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)widget.onMonthChanged?.call(month);});}
  bool available(DateTime d){final m=widget.availablePrayersByDate;if(m==null||widget.availabilityLoading)return true;for(final e in m.entries){if(same(e.key,d))return e.value.isNotEmpty;}return false;}
  bool qaza(DateTime d)=>widget.qazaDates.any((x)=>same(x,d));
  void move(int delta){final n=DateTime(month.year,month.month+delta,1);final min=DateTime(1950);final max=DateTime(today.year,today.month,1);if(n.isBefore(min)||n.isAfter(max))return;setState(()=>month=n);widget.onMonthChanged?.call(n);}
  String hijri(DateTime d){final h=HijriCalendar.fromDate(d);return '${h.hDay} ${h.getLongMonthName()} ${h.hYear} AH';}
  @override Widget build(BuildContext context){final s=ref.watch(calendarControllerProvider);final t=Theme.of(context);final min=DateTime(1950);final selected=s.selectedDates;final canPrev=month.isAfter(min),canNext=month.isBefore(DateTime(today.year,today.month,1));return Column(children:[Row(children:[IconButton(key:const Key('calendar_prev_month'),onPressed:canPrev?()=>move(-1):null,icon:const Icon(Icons.chevron_left_rounded)),Expanded(child:Column(children:[Text(MaterialLocalizations.of(context).formatMonthYear(month),key:const Key('calendar_month_header'),style:t.textTheme.titleMedium),Text(hijri(month),key:const Key('calendar_hijri_month_label'),style:t.textTheme.bodySmall)])),IconButton(key:const Key('calendar_next_month'),onPressed:canNext?()=>move(1):null,icon:const Icon(Icons.chevron_right_rounded))]),if(widget.availabilityLoading)const LinearProgressIndicator(minHeight:2),const SizedBox(height:8),Text(s.hasSelection?'${s.selectedCount} dates selected.':'Tap an available date to select it.',key:const Key('calendar_selection_prompt')),const SizedBox(height:12),_Grid(anchor:month,today:today,state:s,onTap:(d)=>ref.read(calendarControllerProvider.notifier).select(d),available:available,qaza:qaza,hijri:hijri),if(selected.isNotEmpty)Card(key:const Key('calendar_selected_summary'),child:Column(children:[...selected.map((d)=>ListTile(dense:true,title:Text(MaterialLocalizations.of(context).formatMediumDate(d)),subtitle:Text(hijri(d)))),TextButton(key:const Key('calendar_clear_selection'),onPressed:()=>ref.read(calendarControllerProvider.notifier).clear(),child:const Text('Clear'))]))]);}
}
class _Grid extends StatelessWidget{
  const _Grid({required this.anchor,required this.today,required this.state,required this.onTap,required this.available,required this.qaza,required this.hijri});
  final DateTime anchor,today;final CalendarSelectionState state;final ValueChanged<DateTime> onTap;final bool Function(DateTime) available,qaza;final String Function(DateTime) hijri;
  bool same(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
  bool selected(DateTime d)=>state.selectedDates.any((x)=>same(x,d));
  bool inRange(DateTime d)=>state.selectionMode==DateSelectionMode.range&&state.selectedDates.length==2&&!d.isBefore(state.selectedDates.first)&&!d.isAfter(state.selectedDates.last);
  @override Widget build(BuildContext context){final days=DateTime(anchor.year,anchor.month+1,0).day,lead=anchor.weekday-1,total=((lead+days+6)~/7)*7;return Column(children:[const Row(children:[for(final x in ['Mo','Tu','We','Th','Fr','Sa','Su'])Expanded(child:Center(child:Text(x)))]),SizedBox(height:(total~/7)*44,child:Column(children:[for(var r=0;r<total~/7;r++)SizedBox(height:44,child:Row(children:[for(var c=0;c<7;c++)SizedBox(width:44,child:_cell(context,r*7+c,lead,days))]))]))]);}
  Widget _cell(BuildContext context,int i,int lead,int days){final n=i-lead+1;if(n<1||n>days)return const SizedBox.shrink();final d=DateTime(anchor.year,anchor.month,n),ok=!d.isAfter(today)&&!d.isBefore(DateTime(1950))&&available(d),sel=selected(d),range=inRange(d);final cs=Theme.of(context).colorScheme;final key='${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';return Semantics(label:'${MaterialLocalizations.of(context).formatMediumDate(d)}, ${hijri(d)}${ok?'':', unavailable'}',button:ok,selected:sel,child:InkWell(key:Key('calendar_day_$key'),onTap:ok?()=>onTap(d):null,borderRadius:BorderRadius.circular(22),child:Stack(alignment:Alignment.center,children:[Container(width:34,height:34,decoration:BoxDecoration(shape:BoxShape.circle,color:sel?cs.primary:range?cs.primaryContainer:same(d,today)&&ok?cs.secondaryContainer:null),alignment:Alignment.center,child:Text('$n',style:Theme.of(context).textTheme.bodySmall?.copyWith(color:sel?cs.onPrimary:ok?null:cs.onSurfaceVariant.withValues(alpha:.45),fontWeight:sel||same(d,today)?FontWeight.w700:null))),if(qaza(d))Positioned(bottom:2,child:Container(width:5,height:5,decoration:BoxDecoration(shape:BoxShape.circle,color:cs.tertiary)))])));}
}
