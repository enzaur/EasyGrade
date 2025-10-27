import { read, utils } from "xlsx";

export interface StudentRow {
  No: number | string;
  Code: string;
  Name: string;
}

export function parseExcel(file: File): Promise<StudentRow[]> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = (e) => {
      const arrayBuffer = e.target?.result;
      if (!arrayBuffer) return resolve([]);

      const workbook = read(arrayBuffer, { type: "array" });
      const sheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[sheetName];

      const json = utils.sheet_to_json(worksheet, { defval: "" });

      const data: StudentRow[] = json
        .map((row: any, index) => ({
          No: row["No"] || index + 1,
          Code: row["Code"] || "",
          Name: row["Name"]
            ? row["Name"]
                .toString()
                .toLowerCase()
                .split(" ")
                .map((w: string) => w.charAt(0).toUpperCase() + w.slice(1))
                .join(" ")
            : "",
        }))
        .filter((row) => row.Code && row.Name);

      resolve(data);
    };

    reader.onerror = (err) => reject(err);

    reader.readAsArrayBuffer(file);
  });
}
