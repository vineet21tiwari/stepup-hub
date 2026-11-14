// Excel (.xlsx) and PDF exports of an attendance report built by utils/attendance.buildReport.
// The libraries are imported lazily so they only download when someone actually exports.
import { fmtClock, fmtDuration, fmtShortDate } from "./attendance";

function safeFileName(s) {
  return (s || "attendance").replace(/[^a-z0-9]+/gi, "-").replace(/^-+|-+$/g, "").toLowerCase() || "attendance";
}

function downloadBlob(blob, fileName) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function classRow(c, isStudentView) {
  const base = [
    fmtShortDate(c.scheduledStart),
    `${fmtClock(c.scheduledStart)} - ${fmtClock(c.scheduledEnd)}`,
    c.teacherName,
    c.marked ? fmtDuration(c.durationMinutes) : "-",
    c.marked ? (c.teacherPresent ? "Present" : "Absent") : "-",
  ];
  if (isStudentView) return [...base, c.marked ? (c.selfPresent ? "Present" : "Absent") : "Not marked"];
  return [
    ...base,
    c.marked ? `${c.presentCount}/${c.totalStudents}` : "Not marked",
    c.absentNames.join(", "),
  ];
}

function classHeaders(isStudentView) {
  const base = ["Date", "Time (IST)", "Teacher", "Duration", "Teacher present"];
  return isStudentView ? [...base, "You"] : [...base, "Students present", "Absent"];
}

function summaryRows(report, isStudentView) {
  const s = report.summary;
  return [
    ["Classes held", s.held],
    ["Attendance marked", s.marked],
    ["Not marked yet", s.pending],
    [isStudentView ? "Your attendance" : "Average student attendance", s.attendancePercent == null ? "-" : `${s.attendancePercent}%`],
    ["Teacher attendance", s.teacherPercent == null ? "-" : `${s.teacherPercent}%`],
    ["Time taught", fmtDuration(s.minutes)],
  ];
}

export async function exportAttendanceExcel({ courseTitle, periodLabel, report, isStudentView }) {
  const { default: ExcelJS } = await import("exceljs");
  const wb = new ExcelJS.Workbook();
  wb.creator = "StepUp Hub";
  wb.created = new Date();

  const navy = "FF1A4C8B";
  const styleHeader = (row) => {
    row.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: navy } };
      cell.alignment = { vertical: "middle" };
    });
    row.height = 20;
  };

  // Summary
  const sum = wb.addWorksheet("Summary");
  sum.columns = [{ width: 30 }, { width: 22 }];
  sum.addRow([`${courseTitle} - Attendance`]).font = { bold: true, size: 14, color: { argb: navy } };
  sum.addRow([`Period: ${periodLabel}`]);
  sum.addRow([`Generated: ${new Date().toLocaleString(undefined, { timeZone: "Asia/Kolkata" })} IST`]);
  sum.addRow([]);
  summaryRows(report, isStudentView).forEach((r) => {
    const row = sum.addRow(r);
    row.getCell(1).font = { bold: true };
    row.getCell(2).alignment = { horizontal: "right" };
  });

  // Classes
  const cls = wb.addWorksheet("Classes");
  const headers = classHeaders(isStudentView);
  cls.columns = headers.map((h, i) => ({ width: [24, 18, 22, 12, 12, 18, 40][i] || 16 }));
  styleHeader(cls.addRow(headers));
  report.classes.forEach((c) => {
    const row = cls.addRow(classRow(c, isStudentView));
    if (!c.marked) row.font = { italic: true, color: { argb: "FFB8720A" } };
  });
  cls.views = [{ state: "frozen", ySplit: 1 }];

  // Students
  const st = wb.addWorksheet(isStudentView ? "My attendance" : "Students");
  st.columns = [{ width: 28 }, { width: 16 }, { width: 12 }, { width: 12 }, { width: 14 }];
  styleHeader(st.addRow(["Student", "Classes marked", "Attended", "Missed", "Attendance %"]));
  report.students.forEach((r) => {
    const row = st.addRow([r.name, r.total, r.attended, r.missed, r.percent / 100]);
    row.getCell(5).numFmt = "0%";
    if (r.percent < 75) row.getCell(5).font = { bold: true, color: { argb: r.percent < 50 ? "FFC62828" : "FFB8720A" } };
  });
  st.views = [{ state: "frozen", ySplit: 1 }];

  const buf = await wb.xlsx.writeBuffer();
  downloadBlob(
    new Blob([buf], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }),
    `${safeFileName(courseTitle)}-attendance-${safeFileName(periodLabel)}.xlsx`
  );
}

export async function exportAttendancePdf({ courseTitle, periodLabel, report, isStudentView }) {
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([import("jspdf"), import("jspdf-autotable")]);
  const doc = new jsPDF({ orientation: "landscape", unit: "pt", format: "a4" });
  const navy = [26, 76, 139];
  const orange = [242, 148, 29];
  const pageW = doc.internal.pageSize.getWidth();
  const margin = 40;

  // Header band
  doc.setFillColor(...navy);
  doc.rect(0, 0, pageW, 64, "F");
  doc.setFillColor(...orange);
  doc.rect(0, 64, pageW, 4, "F");
  doc.setTextColor(255, 255, 255);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(18);
  doc.text(`${courseTitle} - Attendance`, margin, 30);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(10);
  doc.text(`Period: ${periodLabel}`, margin, 48);
  doc.text(`Generated ${new Date().toLocaleString(undefined, { timeZone: "Asia/Kolkata" })} IST`, pageW - margin, 48, { align: "right" });

  // Summary tiles
  const tiles = summaryRows(report, isStudentView);
  const tileW = (pageW - margin * 2 - 10 * (tiles.length - 1)) / tiles.length;
  tiles.forEach(([label, value], i) => {
    const x = margin + i * (tileW + 10);
    doc.setDrawColor(226, 230, 238);
    doc.setFillColor(245, 247, 251);
    doc.roundedRect(x, 86, tileW, 50, 6, 6, "FD");
    doc.setTextColor(...navy);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(15);
    doc.text(String(value), x + 10, 108);
    doc.setTextColor(102, 112, 127);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(8);
    doc.text(label.toUpperCase(), x + 10, 125);
  });

  const tableStyles = {
    theme: "grid",
    styles: { fontSize: 9, cellPadding: 5, lineColor: [226, 230, 238], textColor: [36, 48, 63] },
    headStyles: { fillColor: navy, textColor: 255, fontStyle: "bold" },
    alternateRowStyles: { fillColor: [245, 247, 251] },
    margin: { left: margin, right: margin },
  };

  doc.setTextColor(...navy);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(12);
  doc.text("Class-wise register", margin, 162);
  autoTable(doc, {
    ...tableStyles,
    startY: 170,
    head: [classHeaders(isStudentView)],
    body: report.classes.map((c) => classRow(c, isStudentView)),
    didParseCell: (data) => {
      if (data.section !== "body") return;
      const v = String(data.cell.raw);
      if (v === "Not marked") data.cell.styles.textColor = [184, 114, 10];
      if (v === "Absent") data.cell.styles.textColor = [198, 40, 40];
      if (v === "Present") data.cell.styles.textColor = [28, 138, 75];
    },
  });

  if (report.students.length) {
    let y = (doc.lastAutoTable?.finalY || 170) + 28;
    if (y > doc.internal.pageSize.getHeight() - 80) {
      doc.addPage();
      y = 50;
    }
    doc.setTextColor(...navy);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(12);
    doc.text(isStudentView ? "Your attendance" : "Student-wise summary", margin, y);
    autoTable(doc, {
      ...tableStyles,
      startY: y + 8,
      head: [["Student", "Classes marked", "Attended", "Missed", "Attendance %"]],
      body: report.students.map((r) => [r.name, r.total, r.attended, r.missed, `${r.percent}%`]),
      didParseCell: (data) => {
        if (data.section !== "body" || data.column.index !== 4) return;
        const p = parseInt(data.cell.raw, 10);
        data.cell.styles.fontStyle = "bold";
        data.cell.styles.textColor = p >= 75 ? [28, 138, 75] : p >= 50 ? [184, 114, 10] : [198, 40, 40];
      },
    });
  }

  // Page footer
  const pages = doc.getNumberOfPages();
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setTextColor(140, 150, 165);
    doc.text(`StepUp Hub · Page ${i} of ${pages}`, pageW / 2, doc.internal.pageSize.getHeight() - 18, { align: "center" });
  }

  doc.save(`${safeFileName(courseTitle)}-attendance-${safeFileName(periodLabel)}.pdf`);
}
