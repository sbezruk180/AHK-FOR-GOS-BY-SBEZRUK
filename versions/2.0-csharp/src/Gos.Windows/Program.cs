using System.Text;
namespace Gos.Windows;
internal static class Program
{
    [STAThread]
    static int Main(string[] args)
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        using var singleton=new Mutex(true,@"Local\SBezruk.Gos.CSharp.V2",out bool first);
        if(!first){MessageBox.Show("GOS 2 уже запущен. Закройте прежнюю копию через значок возле часов и откройте новую версию.","GOS 2",MessageBoxButtons.OK,MessageBoxIcon.Information);return 2;}
        if(args.Contains("--ui-selftest"))Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
        ApplicationConfiguration.Initialize();
        string data=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"AHK FOR GOS","v2");
        Directory.CreateDirectory(data);
        if(args.Contains("--ui-selftest"))return NativeSelfTest.Run(args.SkipWhile(a=>a!="--ui-selftest").Skip(1).FirstOrDefault()??Path.Combine(Path.GetTempPath(),"gos-v2-native-"+Environment.ProcessId));
        Application.ThreadException+=(_,e)=>Report(data,e.Exception);
        AppDomain.CurrentDomain.UnhandledException+=(_,e)=>Report(data,e.ExceptionObject as Exception??new Exception("Unexpected runtime failure"));
        try
        {
            using var controller=new AppController(data);
            using var shell=new ShellForm(controller);
            using var palette=new CommandForm(controller);
            using var hud=new HudForm(controller);
            using var nearby=new NearbyForm(controller);
            controller.Attach(shell,palette,hud,nearby);
            using var tray=new NotifyIcon {Icon=SystemIcons.Application,Text="GOS 2 · Меню и команды",Visible=true,ContextMenuStrip=new()};
            tray.ContextMenuStrip.Items.Add("Открыть меню",null,(_,_)=>shell.ShowPassive());
            tray.ContextMenuStrip.Items.Add("Окно команд",null,(_,_)=>palette.Open());
            tray.ContextMenuStrip.Items.Add("Остановить действия",null,(_,_)=>controller.Cancel());
            tray.ContextMenuStrip.Items.Add("Выход",null,(_,_)=>{controller.Cancel();Application.Exit();});
            tray.DoubleClick+=(_,_)=>shell.ShowPassive();
            shell.ShowPassive();
            Application.Run();
            tray.Visible=false;
            return 0;
        }
        catch(Exception e){Report(data,e);MessageBox.Show("Не удалось запустить GOS 2.\n"+e.Message,"GOS",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
    }
    static void Report(string data,Exception e)
    {try{File.AppendAllText(Path.Combine(data,"errors.log"),$"{DateTimeOffset.Now:O} {e}\n");}catch(IOException){}catch(UnauthorizedAccessException){}}
}
