use tsv_to_ansi_table::{Config, Engine, Error, render_table};

#[test]
fn render_numeric_alignment_and_sanitize_controls() {
	let config = Config::parse(&["--plain"], Config::default()).unwrap();
	assert_eq!(render_table(&config, &[&["Name", "N"], &["a", "12"]]).unwrap(), "Name   N\na     12\n");
	assert_eq!(render_table(&config, &[&["a\0b\t\nx"]]).unwrap(), "a�b��x\n");
	assert_eq!(render_table(&config, &[]).unwrap(), "");
	assert_eq!(render_table(&config, &[&["a", "b"], &["1"]]), Err(Error::RaggedRow));
}

#[test]
fn fixed_width_output_arrives_before_finish() {
	let config = Config::parse(&["--plain", "--widths", "4,2"], Config::default()).unwrap();
	let mut engine = Engine::new(config).unwrap();
	assert_eq!(engine.push(&["Name", "N"]).unwrap(), "");
	assert_eq!(engine.push(&["a", "12"]).unwrap(), "Name   N\na     12\n");
	assert_eq!(engine.finish().unwrap(), "");
	assert_eq!(engine.finish(), Err(Error::InvalidState));
}

#[test]
fn failed_context_cannot_continue_and_instances_are_independent() {
	let mut broken = Engine::new(Config::default()).unwrap();
	let mut good = Engine::new(Config::parse(&["--plain"], Config::default()).unwrap()).unwrap();
	broken.push(&["a", "b"]).unwrap();
	assert_eq!(broken.push(&["1"]), Err(Error::RaggedRow));
	assert_eq!(broken.finish(), Err(Error::InvalidState));
	good.push(&["ok"]).unwrap();
	assert_eq!(good.finish().unwrap(), "ok\n");
}
